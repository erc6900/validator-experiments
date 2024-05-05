// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {UserOperation} from "modular-account-libs/interfaces/IPlugin.sol";
import {IValidator, ValidationLocator} from "./IValidator.sol";

/**
 * Validator which defines validations which define a threshold and a list of
 * other validator "owners". Then to pass validation, the signature must contain
 * valid signatures from at least the threshold number of owners.
 *
 * Before it can be used by a smart contract account, that account must
 * "register" a threshold and list of owners via the `registerValidation`
 * function, which returns a validation id. This id must be passed when that
 * account wants to use this validator.
 */
contract ThresholdValidator is IValidator {
    /**
     * This validator accepts signatures which are the ABI-encoding of an array
     * of this struct.
     */
    struct SignaturePart {
        uint256 ownerIndex;
        bytes ownerSignature;
    }

    mapping(bytes32 => mapping(address => uint256)) public thresholdsByAccountByValidatorId;
    mapping(bytes32 => mapping(address => ValidationLocator)) public ownersByAccountByKey;

    function registerValidation(ValidationLocator[] calldata owners, uint256 threshold)
        external
        returns (bytes32 validatorId)
    {
        require(threshold > 0, "Threshold must be positive");
        require(owners.length >= threshold, "Not enough owners for threshold");
        validatorId = keccak256(abi.encode(owners, threshold));
        thresholdsByAccountByValidatorId[validatorId][msg.sender] = threshold;
        for (uint256 ownerIndex = 0; ownerIndex < owners.length; ownerIndex++) {
            bytes32 key = _getKey(validatorId, ownerIndex);
            ownersByAccountByKey[key][msg.sender] = owners[ownerIndex];
        }
    }

    function validateUserOp(
        address account,
        bytes32 validatorId,
        UserOperation calldata userOp,
        bytes calldata signature,
        bytes32 userOpHash
    ) external virtual override returns (uint256 validationData) {
        SignaturePart[] memory parts = abi.decode(signature, (SignaturePart[]));
        uint256 threshold = thresholdsByAccountByValidatorId[validatorId][account];
        require(parts.length >= threshold, "Threshold not met");
        // Require that the owner index increases with each part to prevent the
        // threshold being met by a single owner submitting multple parts.
        uint256 previousOwnerIndexPlusOne = 0;
        for (uint256 i = 0; i < parts.length; i++) {
            require(parts[i].ownerIndex >= previousOwnerIndexPlusOne, "Owners repeated or out of order");
            previousOwnerIndexPlusOne = parts[i].ownerIndex + 1;
            bytes32 key = _getKey(validatorId, parts[i].ownerIndex);
            ValidationLocator storage owner = ownersByAccountByKey[key][account];
            // TODO: This should merge the time ranges of the validation data. I'm
            // going to skip that for now and always return 0 (success) or 1
            // (failure).
            uint256 childValidationData =
                owner.validator.validateUserOp(account, owner.validationId, userOp, parts[i].ownerSignature, userOpHash);
            if (childValidationData & 1 == 1) {
                return 1; // Failure
            }
        }
        return 0; // Success
    }

    function _getKey(bytes32 validatorId, uint256 ownerIndex) internal pure returns (bytes32) {
        return keccak256(abi.encode(validatorId, ownerIndex));
    }
}

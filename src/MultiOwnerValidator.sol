// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {UserOperation} from "modular-account-libs/interfaces/IPlugin.sol";
import {IValidator, ValidationLocator} from "./IValidator.sol";

/**
 * Validator which defines validations where several other validations are
 * designated as "owners," and this validation can pass if any owner validation
 * passes.
 *
 * Before it can be used by a smart contract account, that account must
 * "register" a list of owners via the `registerOwners` function, which returns
 * a validation id. This must be passed when that account wants to use this
 * validator.
 */
contract MultiOwnerValidator is IValidator {
    /**
     * This validator accepts signatures which are the ABI-encoding of this
     * struct.
     */
    struct Signature {
        uint256 ownerIndex;
        bytes ownerSignature;
    }

    mapping(bytes32 => mapping(address => ValidationLocator)) public ownersByAccountByKey;

    function registerOwners(ValidationLocator[] calldata owners) external returns (bytes32 validatorId) {
        validatorId = keccak256(abi.encode(owners));
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
        Signature memory decodedSignature = abi.decode(signature, (Signature));
        bytes32 key = _getKey(validatorId, decodedSignature.ownerIndex);
        ValidationLocator storage owner = ownersByAccountByKey[key][account];
        require(address(owner.validator) != address(0), "Owner not found");
        return owner.validator.validateUserOp(
            account, owner.validationId, userOp, decodedSignature.ownerSignature, userOpHash
        );
    }

    function _getKey(bytes32 validatorId, uint256 ownerIndex) internal pure returns (bytes32) {
        return keccak256(abi.encode(validatorId, ownerIndex));
    }
}

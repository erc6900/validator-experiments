// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {UserOperation} from "modular-account-libs/interfaces/IPlugin.sol";
import {IValidator} from "./IValidator.sol";

/**
 * Validator which checks that the user op hash is ECDSA signed by a particular
 * owner.
 *
 * The validator id is the address for the owner. For example, the validation
 * which checks that address 0x00..0123 has signed the user op would use
 * validator id 0x00..0123.
 */
contract EcdsaValidator is IValidator {
    using ECDSA for bytes32;

    function validateUserOp(
        address,
        bytes32 validatorId,
        UserOperation calldata,
        bytes calldata signature,
        bytes32 userOpHash
    ) external virtual override returns (uint256 validationData) {
        address publicKey = address(bytes20(validatorId));
        (address signer, ECDSA.RecoverError err) = userOpHash.toEthSignedMessageHash().tryRecover(signature);
        if (err == ECDSA.RecoverError.NoError && signer == publicKey) {
            return 0; // Success
        }
        return 1; // Failure
    }
}

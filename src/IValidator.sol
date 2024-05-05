// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {UserOperation} from "modular-account-libs/interfaces/IPlugin.sol";

/**
 * A struct containing the required information to identify a validation: the
 * contract that contains it and the id for looking up validation parameters
 * within that contract.
 */
struct ValidationLocator {
    IValidator validator;
    bytes32 validationId;
}

/**
 * An interface for contracts that want to define user op validation behavior. A
 * validator might contain the logic for handling a particular kind of
 * cryptographic signature, like ECDSA, or it might contain logic that composes
 * multiple other validators into a more complex scheme.
 */
abstract contract IValidator {
    /**
     * Validates a user operation as part of ERC-4337's user op validation for
     * smart contract accounts.
     *
     * A single `IValidator` can be used by many different accounts- it is
     * expected, for example, that there will be a singleton `EcdsaValidator`
     * which will be used by all accounts and other validators that wish to
     * use ECDSA signatures. Furthermore, a given account may use the same
     * `IValidator` multiple times, such as an account that makes use of
     * several different ECDSA keys. To allow the same `IValidator` to be used
     * with different configurations, the validator can use the `validationId`
     * param to look up the configuration specific to a particular call. For
     * example, the `EcdsaValidator` might use the `validationId` to look up the
     * public key to check for a particular validation.
     *
     * Unlike ERC-4337's `validateUserOp` function on `IAccount`, this takes a
     * `signature` parameter separate from the user op. Validators that are
     * checking a signature against `userOpHash` should examine this signature
     * rather than the one in the `UserOperation` struct. This enables validator
     * composition, where a parent validator may choose to pass a portion of a
     * more complex signature to a child validator.
     *
     * @dev Must not access storage except for the associated storage of
     *      `account`, as defined in ERC-4337.
     *      Must follow all other ERC-4337 validation restrictions, such as
     *      avoiding banned opcodes.
     *
     * @param account the smart contract account which is currently undergoing
     *      validation.
     * @param validationId id for looking up validation parameters. This is an
     *      arbitrary value determined by each `IValidator` implementation which
     *      it uses to determined which behavior should be used for this call.
     * @param userOp the operation that is about to be executed.
     * @param signature the signature that should be validated. Validators
     *      should example this signature rather than `userOp.signature`.
     * @param userOpHash hash of the user's request data. Can be used as the
     *      basis for `signature`.
     */
    function validateUserOp(
        address account,
        bytes32 validationId,
        UserOperation calldata userOp,
        bytes calldata signature,
        bytes32 userOpHash
    ) external virtual returns (uint256 validationData);
}

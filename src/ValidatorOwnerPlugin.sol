// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {BasePlugin} from "modular-account-libs/plugins/BasePlugin.sol";
import {UpgradeableModularAccount} from "lib/reference-implementation/src/account/UpgradeableModularAccount.sol";
import {IPluginExecutor} from "modular-account-libs/interfaces/IPluginExecutor.sol";
import {IStandardExecutor} from "modular-account-libs/interfaces/IStandardExecutor.sol";
import {
    ManifestFunction,
    ManifestAssociatedFunctionType,
    ManifestAssociatedFunction,
    PluginManifest,
    PluginMetadata,
    UserOperation,
    IPlugin
} from "modular-account-libs/interfaces/IPlugin.sol";
import {IValidator, ValidationLocator} from "./IValidator.sol";

/**
 * This plugin places a single validation rule in full control of the account,
 * similar to `MultiOwnerPlugin`. However, unlike `MultiOwnerPlugin` where that
 * validation rule is always multi-ownership among ECDSA signers, this plugin's
 * validation is determined by a single `IValidator`, which makes any kind of
 * validation logic possible.
 */
contract ValidatorOwnerPlugin is BasePlugin {
    string public constant NAME = "Validator Plugin";
    string public constant VERSION = "1.0.0";
    string public constant AUTHOR = "David Philipson";

    mapping(address => ValidationLocator) public locatorsByAccount;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function changeValidator(ValidationLocator calldata locator) public {
        locatorsByAccount[msg.sender] = locator;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Plugin interface functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc BasePlugin
    function onInstall(bytes calldata data) external override {
        ValidationLocator memory locator = abi.decode(data, (ValidationLocator));
        require(address(locator.validator) != address(0), "Validator address must be set");
        locatorsByAccount[msg.sender] = locator;
    }

    /// @inheritdoc BasePlugin
    function onUninstall(bytes calldata) external override {
        delete locatorsByAccount[msg.sender];
    }

    /// @inheritdoc BasePlugin
    function userOpValidationFunction(uint8, UserOperation calldata userOp, bytes32 userOpHash)
        external
        override
        returns (uint256)
    {
        ValidationLocator storage locator = locatorsByAccount[msg.sender];
        return locator.validator.validateUserOp(msg.sender, locator.validationId, userOp, userOp.signature, userOpHash);
    }

    /// @inheritdoc BasePlugin
    function pluginManifest() external pure override returns (PluginManifest memory) {
        PluginManifest memory manifest;

        manifest.dependencyInterfaceIds = new bytes4[](1);
        manifest.dependencyInterfaceIds[0] = type(IPlugin).interfaceId;

        manifest.executionFunctions = new bytes4[](1);
        manifest.executionFunctions[0] = this.changeValidator.selector;

        ManifestFunction memory ownerUserOpValidationFunction = ManifestFunction({
            functionType: ManifestAssociatedFunctionType.SELF,
            functionId: 0, // Not used because we only have one validation.
            dependencyIndex: 0 // Unused.
        });

        // Update Modular Account's native functions to use userOpValidationFunction provided by this plugin
        // The view functions `isValidSignature` and `eip712Domain` are excluded from being assigned a user
        // operation validation function since they should only be called via the runtime path.
        manifest.userOpValidationFunctions = new ManifestAssociatedFunction[](6);
        manifest.userOpValidationFunctions[0] = ManifestAssociatedFunction({
            executionSelector: this.changeValidator.selector,
            associatedFunction: ownerUserOpValidationFunction
        });
        manifest.userOpValidationFunctions[1] = ManifestAssociatedFunction({
            executionSelector: IStandardExecutor.execute.selector,
            associatedFunction: ownerUserOpValidationFunction
        });
        manifest.userOpValidationFunctions[2] = ManifestAssociatedFunction({
            executionSelector: IStandardExecutor.executeBatch.selector,
            associatedFunction: ownerUserOpValidationFunction
        });
        manifest.userOpValidationFunctions[3] = ManifestAssociatedFunction({
            executionSelector: UpgradeableModularAccount.installPlugin.selector,
            associatedFunction: ownerUserOpValidationFunction
        });
        manifest.userOpValidationFunctions[4] = ManifestAssociatedFunction({
            executionSelector: UpgradeableModularAccount.uninstallPlugin.selector,
            associatedFunction: ownerUserOpValidationFunction
        });
        manifest.userOpValidationFunctions[5] = ManifestAssociatedFunction({
            executionSelector: UUPSUpgradeable.upgradeToAndCall.selector,
            associatedFunction: ownerUserOpValidationFunction
        });

        return manifest;
    }

    /// @inheritdoc BasePlugin
    function pluginMetadata() external pure virtual override returns (PluginMetadata memory) {
        PluginMetadata memory metadata;
        metadata.name = NAME;
        metadata.version = VERSION;
        metadata.author = AUTHOR;
        return metadata;
    }
}

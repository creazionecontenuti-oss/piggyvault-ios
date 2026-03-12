// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPiggyModule} from "./interfaces/IPiggyModule.sol";

/// @title PiggyVaultGuard - Transaction guard for Safe smart accounts
/// @notice This guard is set on a Safe to enforce all active PiggyVault lock rules.
///         It checks every transaction before execution and reverts if it attempts
///         to transfer a locked token (ERC-20 transfer or transferFrom).
///         The guard reads lock status from registered IPiggyModule contracts.
///
/// @dev Implements the Safe ITransactionGuard interface.
///      The guard maintains a registry of active lock modules per Safe.
///      Only the Safe itself can register/unregister modules (via execTransaction).
contract PiggyVaultGuard {
    // ERC-20 function selectors
    bytes4 private constant TRANSFER_SELECTOR = 0xa9059cbb; // transfer(address,uint256)
    bytes4 private constant TRANSFER_FROM_SELECTOR = 0x23b872dd; // transferFrom(address,address,uint256)
    bytes4 private constant APPROVE_SELECTOR = 0x095ea7b3; // approve(address,uint256)

    // Safe module management selectors
    bytes4 private constant ENABLE_MODULE_SELECTOR = 0x610b5925; // enableModule(address)
    bytes4 private constant DISABLE_MODULE_SELECTOR = 0xe009cfde; // disableModule(address,address)
    // Guard management selectors
    bytes4 private constant UNREGISTER_MODULE_SELECTOR = 0x64b18c57; // unregisterModule(address)
    bytes4 private constant SET_GUARD_SELECTOR = 0xe19a9dd9; // setGuard(address)

    /// @notice Mapping: safe => array of active lock module addresses
    mapping(address => address[]) public lockModules;

    /// @notice Mapping: safe => module => index+1 in lockModules array (0 = not registered)
    mapping(address => mapping(address => uint256)) public moduleIndex;

    event LockModuleRegistered(address indexed safe, address indexed module);
    event LockModuleUnregistered(address indexed safe, address indexed module);
    event TransactionBlocked(address indexed safe, address indexed token, address indexed module);

    error TokenLocked(address token, address module);
    error ModuleStillLocked(address module);
    error CannotRemoveGuardWhileModulesActive();
    error NotSafe();
    error ModuleAlreadyRegistered();
    error ModuleNotRegistered();

    /// @notice Register a lock module for the calling Safe
    /// @param module The IPiggyModule contract address to register
    function registerModule(address module) external {
        address safe = msg.sender;
        if (moduleIndex[safe][module] != 0) revert ModuleAlreadyRegistered();

        // Verify the module is a valid IPiggyModule bound to this Safe
        IPiggyModule piggyModule = IPiggyModule(module);
        require(piggyModule.safe() == safe, "Module not bound to this Safe");

        lockModules[safe].push(module);
        moduleIndex[safe][module] = lockModules[safe].length; // 1-indexed

        emit LockModuleRegistered(safe, module);
    }

    /// @notice Unregister a lock module for the calling Safe
    /// @param module The module address to unregister
    function unregisterModule(address module) external {
        address safe = msg.sender;
        uint256 idx = moduleIndex[safe][module];
        if (idx == 0) revert ModuleNotRegistered();

        // Swap-and-pop to remove from array
        uint256 lastIdx = lockModules[safe].length;
        if (idx != lastIdx) {
            address lastModule = lockModules[safe][lastIdx - 1];
            lockModules[safe][idx - 1] = lastModule;
            moduleIndex[safe][lastModule] = idx;
        }
        lockModules[safe].pop();
        delete moduleIndex[safe][module];

        emit LockModuleUnregistered(safe, module);
    }

    /// @notice Safe ITransactionGuard: called before transaction execution
    /// @dev Reverts if the transaction attempts to transfer a locked token
    function checkTransaction(
        address to,
        uint256, /* value */
        bytes memory data,
        uint8, /* operation */
        uint256, /* safeTxGas */
        uint256, /* baseGas */
        uint256, /* gasPrice */
        address, /* gasToken */
        address payable, /* refundReceiver */
        bytes memory, /* signatures */
        address /* msgSender */
    ) external view {
        if (data.length < 4) return;

        bytes4 selector = bytes4(data[0]) | (bytes4(data[1]) >> 8) | (bytes4(data[2]) >> 16) | (bytes4(data[3]) >> 24);

        // Check if this is an ERC-20 transfer or approve to the token contract
        if (
            selector == TRANSFER_SELECTOR || selector == TRANSFER_FROM_SELECTOR || selector == APPROVE_SELECTOR
        ) {
            // `to` is the token contract address in an ERC-20 call
            _checkTokenLocks(msg.sender, to);
        }

        // Block disableModule on the Safe itself if the module is still locked
        if (to == msg.sender && selector == DISABLE_MODULE_SELECTOR && data.length >= 68) {
            // disableModule(address prevModule, address module) — module is 2nd param at offset 36
            address moduleToDisable;
            assembly { moduleToDisable := mload(add(data, 68)) }
            _checkModuleNotLocked(msg.sender, moduleToDisable);
        }

        // Block unregisterModule on this guard if the module is still locked
        if (to == address(this) && selector == UNREGISTER_MODULE_SELECTOR && data.length >= 36) {
            address moduleToUnregister;
            assembly { moduleToUnregister := mload(add(data, 36)) }
            _checkModuleNotLocked(msg.sender, moduleToUnregister);
        }

        // Block setGuard(address(0)) on the Safe if any registered module is still locked
        if (to == msg.sender && selector == SET_GUARD_SELECTOR) {
            _checkNoLockedModules(msg.sender);
        }
    }

    /// @notice Safe ITransactionGuard: called after transaction execution (no-op)
    function checkAfterExecution(bytes32, bool) external pure {
        // No post-execution checks needed
    }

    /// @notice Get all active lock modules for a Safe
    function getModules(address safe) external view returns (address[] memory) {
        return lockModules[safe];
    }

    /// @notice Get the number of active lock modules for a Safe
    function getModuleCount(address safe) external view returns (uint256) {
        return lockModules[safe].length;
    }

    /// @notice Check if a specific token is locked for a Safe
    function isTokenLocked(address safe, address token) external view returns (bool) {
        address[] storage modules = lockModules[safe];
        for (uint256 i = 0; i < modules.length; i++) {
            IPiggyModule module = IPiggyModule(modules[i]);
            if (module.token() == token && module.isLocked()) {
                return true;
            }
        }
        return false;
    }

    // MARK: - Internal

    function _checkTokenLocks(address safe, address tokenAddress) internal view {
        address[] storage modules = lockModules[safe];
        for (uint256 i = 0; i < modules.length; i++) {
            IPiggyModule module = IPiggyModule(modules[i]);
            if (module.token() == tokenAddress && module.isLocked()) {
                revert TokenLocked(tokenAddress, address(module));
            }
        }
    }

    /// @dev Revert if the specified module is registered and still locked
    function _checkModuleNotLocked(address safe, address module) internal view {
        uint256 idx = moduleIndex[safe][module];
        if (idx == 0) return; // Not registered with guard, allow
        IPiggyModule piggyModule = IPiggyModule(module);
        if (piggyModule.isLocked()) {
            revert ModuleStillLocked(module);
        }
    }

    /// @dev Revert if any registered module is still locked (used to protect guard removal)
    function _checkNoLockedModules(address safe) internal view {
        address[] storage modules = lockModules[safe];
        for (uint256 i = 0; i < modules.length; i++) {
            IPiggyModule module = IPiggyModule(modules[i]);
            if (module.isLocked()) {
                revert CannotRemoveGuardWhileModulesActive();
            }
        }
    }
}

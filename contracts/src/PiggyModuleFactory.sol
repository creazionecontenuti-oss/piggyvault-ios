// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PiggyTimeLock} from "./PiggyTimeLock.sol";
import {PiggyTargetLock} from "./PiggyTargetLock.sol";
import {PiggyVaultGuard} from "./PiggyVaultGuard.sol";

/// @title PiggyModuleFactory - Deterministic deployment of PiggyVault lock modules
/// @notice Uses CREATE2 for deterministic addresses so the iOS app can predict
///         module addresses before deployment. Each (safe, token, params) combination
///         produces a unique, predictable address.
contract PiggyModuleFactory {
    PiggyVaultGuard public immutable guard_;

    /// @notice Mapping to track deployed modules: salt => deployed address
    mapping(bytes32 => address) public deployedModules;

    event TimeLockDeployed(address indexed safe, address indexed module, address token, uint256 unlockTimestamp);
    event TargetLockDeployed(address indexed safe, address indexed module, address token, uint256 targetAmount);

    error AlreadyDeployed();
    error DeploymentFailed();

    constructor(PiggyVaultGuard _guard) {
        guard_ = _guard;
    }

    /// @notice Deploy a TimeLock module with deterministic address
    /// @param safe The Safe smart account this module protects
    /// @param token The ERC-20 token to lock
    /// @param unlockTimestamp Unix timestamp when the lock expires
    /// @return module The deployed PiggyTimeLock contract address
    function createTimeLock(
        address safe,
        address token,
        uint256 unlockTimestamp
    ) external returns (address module) {
        bytes32 salt = _computeSalt(safe, token, "time_lock", abi.encode(unlockTimestamp));
        if (deployedModules[salt] != address(0)) revert AlreadyDeployed();

        module = address(new PiggyTimeLock{salt: salt}(safe, token, unlockTimestamp));
        if (module == address(0)) revert DeploymentFailed();

        deployedModules[salt] = module;

        emit TimeLockDeployed(safe, module, token, unlockTimestamp);
    }

    /// @notice Deploy a TargetLock module with deterministic address
    /// @param safe The Safe smart account this module protects
    /// @param token The ERC-20 token to lock
    /// @param targetAmount The target balance (in token's smallest unit) to unlock
    /// @return module The deployed PiggyTargetLock contract address
    function createTargetLock(
        address safe,
        address token,
        uint256 targetAmount
    ) external returns (address module) {
        bytes32 salt = _computeSalt(safe, token, "target_lock", abi.encode(targetAmount));
        if (deployedModules[salt] != address(0)) revert AlreadyDeployed();

        module = address(new PiggyTargetLock{salt: salt}(safe, token, targetAmount));
        if (module == address(0)) revert DeploymentFailed();

        deployedModules[salt] = module;

        emit TargetLockDeployed(safe, module, token, targetAmount);
    }

    /// @notice Predict the address of a TimeLock module before deployment
    function predictTimeLockAddress(
        address safe,
        address token,
        uint256 unlockTimestamp
    ) external view returns (address) {
        bytes32 salt = _computeSalt(safe, token, "time_lock", abi.encode(unlockTimestamp));
        bytes memory bytecode = abi.encodePacked(
            type(PiggyTimeLock).creationCode,
            abi.encode(safe, token, unlockTimestamp)
        );
        return _predictAddress(salt, bytecode);
    }

    /// @notice Predict the address of a TargetLock module before deployment
    function predictTargetLockAddress(
        address safe,
        address token,
        uint256 targetAmount
    ) external view returns (address) {
        bytes32 salt = _computeSalt(safe, token, "target_lock", abi.encode(targetAmount));
        bytes memory bytecode = abi.encodePacked(
            type(PiggyTargetLock).creationCode,
            abi.encode(safe, token, targetAmount)
        );
        return _predictAddress(salt, bytecode);
    }

    // MARK: - Internal

    function _computeSalt(
        address safe,
        address token,
        string memory lockType,
        bytes memory params
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(safe, token, lockType, params));
    }

    function _predictAddress(bytes32 salt, bytes memory bytecode) internal view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
        );
        return address(uint160(uint256(hash)));
    }
}

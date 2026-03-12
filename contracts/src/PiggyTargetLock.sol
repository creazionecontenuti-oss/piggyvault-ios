// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPiggyModule} from "./interfaces/IPiggyModule.sol";
import {IERC20} from "./interfaces/IERC20.sol";

/// @title PiggyTargetLock - Target-balance lock module for PiggyVault
/// @notice Prevents withdrawal of a specific ERC-20 token from a Safe until
///         the Safe's balance of that token reaches the target amount.
///         Once the balance >= targetAmount, the lock is permanently lifted.
///         This contract is immutable — once deployed, the target CANNOT be changed.
contract PiggyTargetLock is IPiggyModule {
    address public immutable override safe;
    address public immutable override token;
    uint256 public immutable targetAmount;

    /// @notice Emitted when the module is deployed
    event TargetLockCreated(address indexed safe, address indexed token, uint256 targetAmount);

    error InvalidParams();

    constructor(address _safe, address _token, uint256 _targetAmount) {
        if (_safe == address(0) || _token == address(0)) revert InvalidParams();
        if (_targetAmount == 0) revert InvalidParams();

        safe = _safe;
        token = _token;
        targetAmount = _targetAmount;

        emit TargetLockCreated(_safe, _token, _targetAmount);
    }

    /// @inheritdoc IPiggyModule
    function isLocked() external view override returns (bool) {
        uint256 balance = IERC20(token).balanceOf(safe);
        return balance < targetAmount;
    }

    /// @inheritdoc IPiggyModule
    function lockType() external pure override returns (string memory) {
        return "target_lock";
    }

    /// @notice Current balance of the locked token in the Safe
    function currentBalance() external view returns (uint256) {
        return IERC20(token).balanceOf(safe);
    }

    /// @notice Remaining amount needed to reach the target. Returns 0 if target met.
    function remainingAmount() external view returns (uint256) {
        uint256 balance = IERC20(token).balanceOf(safe);
        if (balance >= targetAmount) return 0;
        return targetAmount - balance;
    }
}

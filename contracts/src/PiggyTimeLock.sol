// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPiggyModule} from "./interfaces/IPiggyModule.sol";

/// @title PiggyTimeLock - Time-based lock module for PiggyVault
/// @notice Prevents withdrawal of a specific ERC-20 token from a Safe until a timestamp is reached.
///         Once block.timestamp >= unlockTimestamp, the lock is permanently lifted.
///         This contract is immutable — once deployed, the unlock time CANNOT be changed.
contract PiggyTimeLock is IPiggyModule {
    address public immutable override safe;
    address public immutable override token;
    uint256 public immutable unlockTimestamp;

    /// @notice Emitted when the module is deployed
    event TimeLockCreated(address indexed safe, address indexed token, uint256 unlockTimestamp);

    error AlreadyUnlocked();
    error InvalidParams();

    constructor(address _safe, address _token, uint256 _unlockTimestamp) {
        if (_safe == address(0) || _token == address(0)) revert InvalidParams();
        if (_unlockTimestamp <= block.timestamp) revert AlreadyUnlocked();

        safe = _safe;
        token = _token;
        unlockTimestamp = _unlockTimestamp;

        emit TimeLockCreated(_safe, _token, _unlockTimestamp);
    }

    /// @inheritdoc IPiggyModule
    function isLocked() external view override returns (bool) {
        return block.timestamp < unlockTimestamp;
    }

    /// @inheritdoc IPiggyModule
    function lockType() external pure override returns (string memory) {
        return "time_lock";
    }

    /// @notice Seconds remaining until unlock. Returns 0 if already unlockable.
    function remainingTime() external view returns (uint256) {
        if (block.timestamp >= unlockTimestamp) return 0;
        return unlockTimestamp - block.timestamp;
    }
}

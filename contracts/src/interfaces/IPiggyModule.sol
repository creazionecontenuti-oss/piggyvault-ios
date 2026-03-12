// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPiggyModule - Interface for PiggyVault lock modules
/// @notice Each module enforces a lock condition on a specific ERC-20 token within a Safe
interface IPiggyModule {
    /// @notice The Safe this module is bound to
    function safe() external view returns (address);

    /// @notice The ERC-20 token address being locked
    function token() external view returns (address);

    /// @notice Whether the lock condition is still active
    /// @return true if the token is still locked, false if unlock conditions are met
    function isLocked() external view returns (bool);

    /// @notice Human-readable description of the lock type
    function lockType() external pure returns (string memory);
}

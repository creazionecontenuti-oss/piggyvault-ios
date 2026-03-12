// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PiggyVaultGuard} from "../src/PiggyVaultGuard.sol";
import {PiggyTimeLock} from "../src/PiggyTimeLock.sol";
import {PiggyTargetLock} from "../src/PiggyTargetLock.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;

    function setBalance(address account, uint256 amount) external {
        balanceOf[account] = amount;
    }
}

contract PiggyVaultGuardTest is Test {
    PiggyVaultGuard public guard_;
    MockERC20 public mockToken;
    address public safe;
    PiggyTimeLock public timeLock;

    function setUp() public {
        safe = address(this); // Tests call guard as the Safe
        guard_ = new PiggyVaultGuard();
        mockToken = new MockERC20();

        uint256 unlockTime = block.timestamp + 30 days;
        timeLock = new PiggyTimeLock(safe, address(mockToken), unlockTime);
    }

    function test_RegisterModule() public {
        guard_.registerModule(address(timeLock));
        assertEq(guard_.getModuleCount(safe), 1);
    }

    function test_RevertOnDuplicateRegister() public {
        guard_.registerModule(address(timeLock));
        vm.expectRevert(PiggyVaultGuard.ModuleAlreadyRegistered.selector);
        guard_.registerModule(address(timeLock));
    }

    function test_UnregisterModule() public {
        guard_.registerModule(address(timeLock));
        guard_.unregisterModule(address(timeLock));
        assertEq(guard_.getModuleCount(safe), 0);
    }

    function test_RevertOnUnregisterNotRegistered() public {
        vm.expectRevert(PiggyVaultGuard.ModuleNotRegistered.selector);
        guard_.unregisterModule(address(timeLock));
    }

    function test_IsTokenLockedWhenLocked() public {
        guard_.registerModule(address(timeLock));
        assertTrue(guard_.isTokenLocked(safe, address(mockToken)));
    }

    function test_IsTokenNotLockedAfterUnlock() public {
        guard_.registerModule(address(timeLock));
        vm.warp(block.timestamp + 31 days);
        assertFalse(guard_.isTokenLocked(safe, address(mockToken)));
    }

    function test_IsTokenNotLockedAfterUnregister() public {
        guard_.registerModule(address(timeLock));
        guard_.unregisterModule(address(timeLock));
        assertFalse(guard_.isTokenLocked(safe, address(mockToken)));
    }

    function test_CheckTransactionBlocksLockedTransfer() public {
        guard_.registerModule(address(timeLock));

        // Build ERC-20 transfer(address,uint256) calldata
        bytes memory transferData = abi.encodeWithSelector(0xa9059cbb, makeAddr("recipient"), uint256(100e6));

        vm.expectRevert(
            abi.encodeWithSelector(PiggyVaultGuard.TokenLocked.selector, address(mockToken), address(timeLock))
        );
        guard_.checkTransaction(
            address(mockToken), // to = token contract
            0,
            transferData,
            0, 0, 0, 0,
            address(0),
            payable(address(0)),
            "",
            address(0)
        );
    }

    function test_CheckTransactionAllowsAfterTimeLockExpires() public {
        guard_.registerModule(address(timeLock));
        vm.warp(block.timestamp + 31 days);

        bytes memory transferData = abi.encodeWithSelector(0xa9059cbb, makeAddr("recipient"), uint256(100e6));

        // Should not revert
        guard_.checkTransaction(
            address(mockToken),
            0,
            transferData,
            0, 0, 0, 0,
            address(0),
            payable(address(0)),
            "",
            address(0)
        );
    }

    function test_CheckTransactionAllowsUnlockedToken() public {
        guard_.registerModule(address(timeLock));
        address otherToken = makeAddr("otherToken");

        bytes memory transferData = abi.encodeWithSelector(0xa9059cbb, makeAddr("recipient"), uint256(100e6));

        // Transfer of a different token should succeed
        guard_.checkTransaction(
            otherToken,
            0,
            transferData,
            0, 0, 0, 0,
            address(0),
            payable(address(0)),
            "",
            address(0)
        );
    }

    function test_CheckTransactionAllowsNonERC20Calls() public {
        guard_.registerModule(address(timeLock));

        // Random function call (not transfer/approve)
        bytes memory randomData = abi.encodeWithSelector(bytes4(0xdeadbeef), uint256(42));

        guard_.checkTransaction(
            address(mockToken),
            0,
            randomData,
            0, 0, 0, 0,
            address(0),
            payable(address(0)),
            "",
            address(0)
        );
    }

    function test_CheckTransactionBlocksApprove() public {
        guard_.registerModule(address(timeLock));

        bytes memory approveData = abi.encodeWithSelector(0x095ea7b3, makeAddr("spender"), uint256(100e6));

        vm.expectRevert(
            abi.encodeWithSelector(PiggyVaultGuard.TokenLocked.selector, address(mockToken), address(timeLock))
        );
        guard_.checkTransaction(
            address(mockToken),
            0,
            approveData,
            0, 0, 0, 0,
            address(0),
            payable(address(0)),
            "",
            address(0)
        );
    }

    function test_MultipleModulesSwapAndPop() public {
        // Create a second lock module
        address otherToken = address(new MockERC20());
        PiggyTimeLock timeLock2 = new PiggyTimeLock(safe, otherToken, block.timestamp + 60 days);

        guard_.registerModule(address(timeLock));
        guard_.registerModule(address(timeLock2));
        assertEq(guard_.getModuleCount(safe), 2);

        // Unregister the first one (tests swap-and-pop)
        guard_.unregisterModule(address(timeLock));
        assertEq(guard_.getModuleCount(safe), 1);

        // The second module should still be tracked
        assertTrue(guard_.isTokenLocked(safe, otherToken));
        assertFalse(guard_.isTokenLocked(safe, address(mockToken)));
    }

    function test_GetModules() public {
        guard_.registerModule(address(timeLock));
        address[] memory modules = guard_.getModules(safe);
        assertEq(modules.length, 1);
        assertEq(modules[0], address(timeLock));
    }

    function test_CheckAfterExecutionIsNoop() public view {
        guard_.checkAfterExecution(bytes32(0), true);
        // Just verifying it doesn't revert
    }

    // ===== Lock Bypass Protection Tests =====

    function test_BlocksDisableModuleWhileLocked() public {
        guard_.registerModule(address(timeLock));

        // Build disableModule(address prevModule, address module) calldata targeting the Safe itself
        bytes memory disableData = abi.encodeWithSelector(0xe009cfde, address(1), address(timeLock));

        vm.expectRevert(
            abi.encodeWithSelector(PiggyVaultGuard.ModuleStillLocked.selector, address(timeLock))
        );
        guard_.checkTransaction(
            safe, // to = Safe itself
            0,
            disableData,
            0, 0, 0, 0,
            address(0),
            payable(address(0)),
            "",
            address(0)
        );
    }

    function test_AllowsDisableModuleAfterUnlock() public {
        guard_.registerModule(address(timeLock));
        vm.warp(block.timestamp + 31 days);

        bytes memory disableData = abi.encodeWithSelector(0xe009cfde, address(1), address(timeLock));

        // Should not revert — module is no longer locked
        guard_.checkTransaction(
            safe,
            0,
            disableData,
            0, 0, 0, 0,
            address(0),
            payable(address(0)),
            "",
            address(0)
        );
    }

    function test_BlocksUnregisterModuleWhileLocked() public {
        guard_.registerModule(address(timeLock));

        // Build unregisterModule(address) calldata targeting the guard
        bytes memory unregisterData = abi.encodeWithSelector(0x64b18c57, address(timeLock));

        vm.expectRevert(
            abi.encodeWithSelector(PiggyVaultGuard.ModuleStillLocked.selector, address(timeLock))
        );
        guard_.checkTransaction(
            address(guard_), // to = guard contract
            0,
            unregisterData,
            0, 0, 0, 0,
            address(0),
            payable(address(0)),
            "",
            address(0)
        );
    }

    function test_AllowsUnregisterModuleAfterUnlock() public {
        guard_.registerModule(address(timeLock));
        vm.warp(block.timestamp + 31 days);

        bytes memory unregisterData = abi.encodeWithSelector(0x64b18c57, address(timeLock));

        // Should not revert
        guard_.checkTransaction(
            address(guard_),
            0,
            unregisterData,
            0, 0, 0, 0,
            address(0),
            payable(address(0)),
            "",
            address(0)
        );
    }

    function test_BlocksSetGuardWhileModulesLocked() public {
        guard_.registerModule(address(timeLock));

        // Build setGuard(address(0)) calldata — attempt to remove guard
        bytes memory setGuardData = abi.encodeWithSelector(0xe19a9dd9, address(0));

        vm.expectRevert(PiggyVaultGuard.CannotRemoveGuardWhileModulesActive.selector);
        guard_.checkTransaction(
            safe, // to = Safe itself
            0,
            setGuardData,
            0, 0, 0, 0,
            address(0),
            payable(address(0)),
            "",
            address(0)
        );
    }

    function test_AllowsSetGuardAfterAllModulesUnlocked() public {
        guard_.registerModule(address(timeLock));
        vm.warp(block.timestamp + 31 days);

        bytes memory setGuardData = abi.encodeWithSelector(0xe19a9dd9, address(0));

        // Should not revert — all modules unlocked
        guard_.checkTransaction(
            safe,
            0,
            setGuardData,
            0, 0, 0, 0,
            address(0),
            payable(address(0)),
            "",
            address(0)
        );
    }

    function test_AllowsDisableUnregisteredModule() public {
        // Module not registered with guard — disableModule should be allowed
        bytes memory disableData = abi.encodeWithSelector(0xe009cfde, address(1), address(timeLock));

        guard_.checkTransaction(
            safe,
            0,
            disableData,
            0, 0, 0, 0,
            address(0),
            payable(address(0)),
            "",
            address(0)
        );
    }
}

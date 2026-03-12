// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PiggyTargetLock} from "../src/PiggyTargetLock.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;

    function setBalance(address account, uint256 amount) external {
        balanceOf[account] = amount;
    }
}

contract PiggyTargetLockTest is Test {
    PiggyTargetLock public targetLock;
    MockERC20 public mockToken;
    address public safe = makeAddr("safe");
    uint256 public target = 1000e6; // 1000 USDC (6 decimals)

    function setUp() public {
        mockToken = new MockERC20();
        targetLock = new PiggyTargetLock(safe, address(mockToken), target);
    }

    function test_InitialState() public view {
        assertEq(targetLock.safe(), safe);
        assertEq(targetLock.token(), address(mockToken));
        assertEq(targetLock.targetAmount(), target);
    }

    function test_IsLockedWhenBelowTarget() public view {
        assertTrue(targetLock.isLocked());
    }

    function test_IsNotLockedWhenTargetReached() public {
        mockToken.setBalance(safe, target);
        assertFalse(targetLock.isLocked());
    }

    function test_IsNotLockedWhenAboveTarget() public {
        mockToken.setBalance(safe, target + 1);
        assertFalse(targetLock.isLocked());
    }

    function test_CurrentBalance() public {
        mockToken.setBalance(safe, 500e6);
        assertEq(targetLock.currentBalance(), 500e6);
    }

    function test_RemainingAmount() public view {
        assertEq(targetLock.remainingAmount(), target);
    }

    function test_RemainingAmountPartial() public {
        mockToken.setBalance(safe, 400e6);
        assertEq(targetLock.remainingAmount(), 600e6);
    }

    function test_RemainingAmountAtTarget() public {
        mockToken.setBalance(safe, target);
        assertEq(targetLock.remainingAmount(), 0);
    }

    function test_RemainingAmountAboveTarget() public {
        mockToken.setBalance(safe, target + 500e6);
        assertEq(targetLock.remainingAmount(), 0);
    }

    function test_LockType() public view {
        assertEq(targetLock.lockType(), "target_lock");
    }

    function test_RevertOnZeroSafe() public {
        vm.expectRevert(PiggyTargetLock.InvalidParams.selector);
        new PiggyTargetLock(address(0), address(mockToken), target);
    }

    function test_RevertOnZeroToken() public {
        vm.expectRevert(PiggyTargetLock.InvalidParams.selector);
        new PiggyTargetLock(safe, address(0), target);
    }

    function test_RevertOnZeroTarget() public {
        vm.expectRevert(PiggyTargetLock.InvalidParams.selector);
        new PiggyTargetLock(safe, address(mockToken), 0);
    }

    function testFuzz_LockedUntilTarget(uint256 balance) public {
        balance = bound(balance, 0, target - 1);
        mockToken.setBalance(safe, balance);
        assertTrue(targetLock.isLocked());
        assertEq(targetLock.remainingAmount(), target - balance);
    }
}

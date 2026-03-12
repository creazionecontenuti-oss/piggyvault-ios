// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PiggyTimeLock} from "../src/PiggyTimeLock.sol";

contract PiggyTimeLockTest is Test {
    PiggyTimeLock public timeLock;
    address public safe = makeAddr("safe");
    address public token = makeAddr("token");
    uint256 public unlockTime;

    function setUp() public {
        unlockTime = block.timestamp + 30 days;
        timeLock = new PiggyTimeLock(safe, token, unlockTime);
    }

    function test_InitialState() public view {
        assertEq(timeLock.safe(), safe);
        assertEq(timeLock.token(), token);
        assertEq(timeLock.unlockTimestamp(), unlockTime);
    }

    function test_IsLockedBeforeUnlockTime() public view {
        assertTrue(timeLock.isLocked());
    }

    function test_IsNotLockedAfterUnlockTime() public {
        vm.warp(unlockTime);
        assertFalse(timeLock.isLocked());
    }

    function test_IsNotLockedAfterUnlockTimePlus() public {
        vm.warp(unlockTime + 1);
        assertFalse(timeLock.isLocked());
    }

    function test_RemainingTime() public view {
        assertEq(timeLock.remainingTime(), 30 days);
    }

    function test_RemainingTimeAtUnlock() public {
        vm.warp(unlockTime);
        assertEq(timeLock.remainingTime(), 0);
    }

    function test_RemainingTimeAfterUnlock() public {
        vm.warp(unlockTime + 100);
        assertEq(timeLock.remainingTime(), 0);
    }

    function test_LockType() public view {
        assertEq(timeLock.lockType(), "time_lock");
    }

    function test_RevertOnZeroSafe() public {
        vm.expectRevert(PiggyTimeLock.InvalidParams.selector);
        new PiggyTimeLock(address(0), token, unlockTime);
    }

    function test_RevertOnZeroToken() public {
        vm.expectRevert(PiggyTimeLock.InvalidParams.selector);
        new PiggyTimeLock(safe, address(0), unlockTime);
    }

    function test_RevertOnPastTimestamp() public {
        vm.expectRevert(PiggyTimeLock.AlreadyUnlocked.selector);
        new PiggyTimeLock(safe, token, block.timestamp);
    }

    function testFuzz_RemainingTimeDecreases(uint256 warpSeconds) public {
        warpSeconds = bound(warpSeconds, 0, 30 days - 1);
        vm.warp(block.timestamp + warpSeconds);
        assertEq(timeLock.remainingTime(), 30 days - warpSeconds);
        assertTrue(timeLock.isLocked());
    }
}

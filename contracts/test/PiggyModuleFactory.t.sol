// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PiggyModuleFactory} from "../src/PiggyModuleFactory.sol";
import {PiggyVaultGuard} from "../src/PiggyVaultGuard.sol";
import {PiggyTimeLock} from "../src/PiggyTimeLock.sol";
import {PiggyTargetLock} from "../src/PiggyTargetLock.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;

    function setBalance(address account, uint256 amount) external {
        balanceOf[account] = amount;
    }
}

contract PiggyModuleFactoryTest is Test {
    PiggyVaultGuard public guard_;
    PiggyModuleFactory public factory;
    MockERC20 public mockToken;
    address public safe = makeAddr("safe");

    function setUp() public {
        guard_ = new PiggyVaultGuard();
        factory = new PiggyModuleFactory(guard_);
        mockToken = new MockERC20();
    }

    // --- TimeLock ---

    function test_CreateTimeLock() public {
        uint256 unlockTime = block.timestamp + 30 days;
        address module = factory.createTimeLock(safe, address(mockToken), unlockTime);

        assertTrue(module != address(0));
        assertEq(PiggyTimeLock(module).safe(), safe);
        assertEq(PiggyTimeLock(module).token(), address(mockToken));
        assertEq(PiggyTimeLock(module).unlockTimestamp(), unlockTime);
        assertTrue(PiggyTimeLock(module).isLocked());
    }

    function test_PredictTimeLockAddress() public {
        uint256 unlockTime = block.timestamp + 30 days;
        address predicted = factory.predictTimeLockAddress(safe, address(mockToken), unlockTime);
        address deployed = factory.createTimeLock(safe, address(mockToken), unlockTime);

        assertEq(predicted, deployed);
    }

    function test_RevertOnDuplicateTimeLock() public {
        uint256 unlockTime = block.timestamp + 30 days;
        factory.createTimeLock(safe, address(mockToken), unlockTime);

        vm.expectRevert(PiggyModuleFactory.AlreadyDeployed.selector);
        factory.createTimeLock(safe, address(mockToken), unlockTime);
    }

    function test_DifferentTimeLockForDifferentParams() public {
        address module1 = factory.createTimeLock(safe, address(mockToken), block.timestamp + 30 days);
        address module2 = factory.createTimeLock(safe, address(mockToken), block.timestamp + 60 days);

        assertTrue(module1 != module2);
    }

    // --- TargetLock ---

    function test_CreateTargetLock() public {
        uint256 target = 1000e6;
        address module = factory.createTargetLock(safe, address(mockToken), target);

        assertTrue(module != address(0));
        assertEq(PiggyTargetLock(module).safe(), safe);
        assertEq(PiggyTargetLock(module).token(), address(mockToken));
        assertEq(PiggyTargetLock(module).targetAmount(), target);
        assertTrue(PiggyTargetLock(module).isLocked());
    }

    function test_PredictTargetLockAddress() public {
        uint256 target = 1000e6;
        address predicted = factory.predictTargetLockAddress(safe, address(mockToken), target);
        address deployed = factory.createTargetLock(safe, address(mockToken), target);

        assertEq(predicted, deployed);
    }

    function test_RevertOnDuplicateTargetLock() public {
        uint256 target = 1000e6;
        factory.createTargetLock(safe, address(mockToken), target);

        vm.expectRevert(PiggyModuleFactory.AlreadyDeployed.selector);
        factory.createTargetLock(safe, address(mockToken), target);
    }

    // --- Cross-module ---

    function test_TimeLockAndTargetLockDifferentAddresses() public {
        address timeLock = factory.createTimeLock(safe, address(mockToken), block.timestamp + 30 days);
        address targetLock = factory.createTargetLock(safe, address(mockToken), 1000e6);

        assertTrue(timeLock != targetLock);
    }

    function test_DeployedModulesTracking() public {
        uint256 unlockTime = block.timestamp + 30 days;
        address module = factory.createTimeLock(safe, address(mockToken), unlockTime);

        bytes32 salt = keccak256(abi.encodePacked(safe, address(mockToken), "time_lock", abi.encode(unlockTime)));
        assertEq(factory.deployedModules(salt), module);
    }
}

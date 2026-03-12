// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PiggyVaultGuard} from "../src/PiggyVaultGuard.sol";
import {PiggyModuleFactory} from "../src/PiggyModuleFactory.sol";

/// @title Deploy - Deployment script for PiggyVault contracts on Base
/// @notice Deploys PiggyVaultGuard and PiggyModuleFactory
///         Usage: forge script script/Deploy.s.sol --rpc-url base --broadcast --verify
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy the Guard
        PiggyVaultGuard guard_ = new PiggyVaultGuard();
        console.log("PiggyVaultGuard deployed at:", address(guard_));

        // Step 2: Deploy the Factory (linked to the guard)
        PiggyModuleFactory factory = new PiggyModuleFactory(guard_);
        console.log("PiggyModuleFactory deployed at:", address(factory));

        vm.stopBroadcast();

        // Output for iOS app configuration
        console.log("\n--- iOS App Configuration ---");
        console.log("PIGGY_GUARD_ADDRESS:", address(guard_));
        console.log("PIGGY_FACTORY_ADDRESS:", address(factory));
    }
}

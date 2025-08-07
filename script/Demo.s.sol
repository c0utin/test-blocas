// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MockDAI.sol";
import "../src/WrappedDAI.sol";
import "../src/Debenture.sol";
import "../src/DAOGovernance.sol";

/**
 * @title Simple Demo Script
 * @notice Demonstrates the basic functionality of all contracts
 */
contract DemoScript is Script {
    function run() external {
        // Use test private key for demo
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== BLOCAS DEFI ECOSYSTEM DEMO ===");
        
        // Deploy contracts
        MockDAI dai = new MockDAI();
        WrappedDAI wrappedDAI = new WrappedDAI(IERC20(address(dai)));
        Debenture debenture = new Debenture(IERC20(address(dai)), "BLOCAS Debenture", "bDAI");
        DAOGovernance dao = new DAOGovernance(IERC20(address(debenture)));
        
        console.log("Contracts deployed:");
        console.log("MockDAI:", address(dai));
        console.log("WrappedDAI:", address(wrappedDAI));
        console.log("Debenture:", address(debenture));
        console.log("DAO:", address(dao));
        
        // Setup and test basic functionality
        dai.mint(msg.sender, 100000 * 1e18);
        
        // Test WrappedDAI
        dai.approve(address(wrappedDAI), 25000 * 1e18);
        wrappedDAI.deposit(25000 * 1e18);
        console.log("Wrapped 25,000 DAI");
        
        // Test Debenture
        dai.approve(address(debenture), 50000 * 1e18);
        debenture.deposit(50000 * 1e18);
        console.log("Created debenture shares");
        
        // Test DAO
        uint256 proposalId = dao.createProposal("Test proposal");
        dao.vote(proposalId, true);
        console.log("Created and voted on proposal");
        
        // Test sell blocking
        debenture.setSellBlocked(msg.sender, true);
        debenture.setSellBlocked(msg.sender, false);
        console.log("Tested sell blocking");
        
        // Test withdrawal
        debenture.withdraw(12500 * 1e18);
        wrappedDAI.withdraw(10000 * 1e18);
        console.log("Tested withdrawals");
        
        vm.stopBroadcast();
        
        console.log("=== DEMO COMPLETE ===");
        console.log("All features tested successfully!");
    }
} 
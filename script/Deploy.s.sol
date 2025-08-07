// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MockDAI.sol";
import "../src/WrappedDAI.sol";
import "../src/Debenture.sol";
import "../src/DAOGovernance.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying contracts with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        // 1. Deploy MockDAI for testing
        MockDAI dai = new MockDAI();
        console.log("MockDAI deployed at:", address(dai));
        console.log("MockDAI initial supply:", dai.totalSupply() / 1e18, "tokens");
        
        // 2. Deploy WrappedDAI
        WrappedDAI wrappedDAI = new WrappedDAI(IERC20(address(dai)));
        console.log("WrappedDAI deployed at:", address(wrappedDAI));
        
        // 3. Deploy Debenture contract
        Debenture debenture = new Debenture(
            IERC20(address(dai)),
            "DAI Debenture Token",
            "dDAI"
        );
        console.log("Debenture deployed at:", address(debenture));
        
        // 4. Deploy DAO Governance using debenture as governance token
        DAOGovernance dao = new DAOGovernance(IERC20(address(debenture)));
        console.log("DAO Governance deployed at:", address(dao));
        
        // 5. Initial setup - mint some DAI to deployer for testing
        uint256 testAmount = 100000 * 1e18; // 100k DAI
        dai.mint(deployer, testAmount);
        console.log("Minted", testAmount / 1e18, "DAI to deployer for testing");
        
        // 6. Approve contracts to spend DAI
        dai.approve(address(wrappedDAI), type(uint256).max);
        dai.approve(address(debenture), type(uint256).max);
        console.log("Approved WrappedDAI and Debenture to spend DAI");
        
        // 7. Make initial deposits to demonstrate functionality
        
        // Wrap some DAI
        uint256 wrapAmount = 10000 * 1e18;
        wrappedDAI.deposit(wrapAmount);
        console.log("Wrapped", wrapAmount / 1e18, "DAI into wDAI");
        console.log("wDAI balance:", wrappedDAI.balanceOf(deployer) / 1e18);
        
        // Create debenture shares
        uint256 debentureAmount = 50000 * 1e18;
        debenture.deposit(debentureAmount);
        console.log("Deposited", debentureAmount / 1e18, "DAI into debenture");
        console.log("Debenture shares:", debenture.balanceOf(deployer) / 1e18);
        console.log("Ownership percentage:", debenture.getOwnershipPercentage(deployer) / 1e16, "%");
        
        // Create a test DAO proposal
        string memory proposalDescription = "Initial test proposal: Allocate 10% of treasury for development";
        uint256 proposalId = dao.createProposal(proposalDescription);
        console.log("Created DAO proposal #", proposalId, ":", proposalDescription);
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("MockDAI:", address(dai));
        console.log("WrappedDAI:", address(wrappedDAI));
        console.log("Debenture:", address(debenture));
        console.log("DAO Governance:", address(dao));
        console.log("Initial Proposal ID:", proposalId);
        console.log("========================\n");
        
        // Log interaction commands
        console.log("=== INTERACTION EXAMPLES ===");
        console.log("To vote on proposal:");
        console.log("cast send", address(dao), '"vote(uint256,bool)"');
        console.log("  Arguments:", proposalId, "true --private-key <YOUR_KEY>");
        console.log("To check proposal status:");
        console.log("cast call", address(dao), '"getProposal(uint256)"', proposalId);
        console.log("To wrap more DAI:");
        console.log("cast send", address(wrappedDAI), '"deposit(uint256)"');
        console.log("  Amount: 1000000000000000000000 --private-key <YOUR_KEY>");
        console.log("===========================");
    }
}

contract DeployTestnet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // For testnet, you might want to use a real DAI testnet address
        // For now, we'll deploy our own MockDAI
        MockDAI dai = new MockDAI();
        WrappedDAI wrappedDAI = new WrappedDAI(IERC20(address(dai)));
        Debenture debenture = new Debenture(
            IERC20(address(dai)),
            "DAI Debenture Token",
            "dDAI"
        );
        DAOGovernance dao = new DAOGovernance(IERC20(address(debenture)));
        
        vm.stopBroadcast();
        
        console.log("Testnet deployment complete:");
        console.log("DAI:", address(dai));
        console.log("WrappedDAI:", address(wrappedDAI));
        console.log("Debenture:", address(debenture));
        console.log("DAO:", address(dao));
    }
}

contract DeployMainnet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Mainnet DAI address
        address DAI_MAINNET = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        
        vm.startBroadcast(deployerPrivateKey);
        
        WrappedDAI wrappedDAI = new WrappedDAI(IERC20(DAI_MAINNET));
        Debenture debenture = new Debenture(
            IERC20(DAI_MAINNET),
            "DAI Debenture Token",
            "dDAI"
        );
        DAOGovernance dao = new DAOGovernance(IERC20(address(debenture)));
        
        vm.stopBroadcast();
        
        console.log("Mainnet deployment complete:");
        console.log("WrappedDAI:", address(wrappedDAI));
        console.log("Debenture:", address(debenture));
        console.log("DAO:", address(dao));
    }
} 
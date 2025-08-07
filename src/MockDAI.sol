// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockDAI
 * @notice Mock DAI token for testing purposes
 * @dev Simple ERC20 implementation with mint function for testing
 */
contract MockDAI is ERC20 {
    constructor() ERC20("Mock DAI", "mDAI") {
        // Mint initial supply to deployer for testing
        _mint(msg.sender, 1000000 * 10**decimals());
    }
    
    /**
     * @notice Mint tokens to an address (for testing)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    /**
     * @notice Get token decimals (18 for DAI)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
} 
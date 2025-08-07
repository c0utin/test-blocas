// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Debenture
 * @notice Represents percentage ownership of underlying tokens
 * @dev Allows stopping sells from specific addresses and tracks ownership percentages
 */
contract Debenture is ERC20, Ownable, ReentrancyGuard {
    IERC20 public immutable underlyingToken;
    
    // Mapping to track if an address is blocked from selling
    mapping(address => bool) public sellBlocked;
    
    // Total underlying tokens backing this debenture
    uint256 public totalUnderlyingBacked;
    
    // Events
    event SellBlocked(address indexed account, bool blocked);
    event UnderlyingDeposited(address indexed depositor, uint256 amount, uint256 sharesIssued);
    event UnderlyingWithdrawn(address indexed withdrawer, uint256 amount, uint256 sharesBurned);
    
    constructor(
        IERC20 _underlyingToken,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        underlyingToken = _underlyingToken;
    }
    
    /**
     * @notice Deposit underlying tokens and receive debenture shares representing ownership percentage
     * @param amount Amount of underlying tokens to deposit
     * @return shares Amount of debenture shares minted
     */
    function deposit(uint256 amount) external nonReentrant returns (uint256 shares) {
        require(amount > 0, "Amount must be greater than 0");
        
        // Calculate shares to mint based on current ratio
        if (totalSupply() == 0) {
            shares = amount; // First deposit: 1:1 ratio
        } else {
            shares = (amount * totalSupply()) / totalUnderlyingBacked;
        }
        
        // Transfer underlying tokens from user
        underlyingToken.transferFrom(msg.sender, address(this), amount);
        
        // Update total backing
        totalUnderlyingBacked += amount;
        
        // Mint debenture shares
        _mint(msg.sender, shares);
        
        emit UnderlyingDeposited(msg.sender, amount, shares);
        return shares;
    }
    
    /**
     * @notice Withdraw underlying tokens by burning debenture shares
     * @param shares Amount of debenture shares to burn
     * @return amount Amount of underlying tokens withdrawn
     */
    function withdraw(uint256 shares) external nonReentrant returns (uint256 amount) {
        require(shares > 0, "Shares must be greater than 0");
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");
        require(!sellBlocked[msg.sender], "Selling is blocked for this address");
        
        // Calculate underlying tokens to return
        amount = (shares * totalUnderlyingBacked) / totalSupply();
        
        // Burn shares
        _burn(msg.sender, shares);
        
        // Update total backing
        totalUnderlyingBacked -= amount;
        
        // Transfer underlying tokens to user
        underlyingToken.transfer(msg.sender, amount);
        
        emit UnderlyingWithdrawn(msg.sender, amount, shares);
        return amount;
    }
    
    /**
     * @notice Get ownership percentage of an address
     * @param account Address to check ownership percentage for
     * @return percentage Ownership percentage (scaled by 1e18 for precision)
     */
    function getOwnershipPercentage(address account) external view returns (uint256 percentage) {
        if (totalSupply() == 0) {
            return 0;
        }
        return (balanceOf(account) * 1e18) / totalSupply();
    }
    
    /**
     * @notice Block or unblock an address from selling (withdrawing)
     * @param account Address to block/unblock
     * @param blocked True to block, false to unblock
     */
    function setSellBlocked(address account, bool blocked) external onlyOwner {
        sellBlocked[account] = blocked;
        emit SellBlocked(account, blocked);
    }
    
    /**
     * @notice Override transfer to prevent blocked addresses from selling
     */
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0)) { // Not minting
            require(!sellBlocked[from], "Transfers blocked for this address");
        }
        super._update(from, to, value);
    }
    
    /**
     * @notice Get the current exchange rate (underlying tokens per share)
     * @return rate Exchange rate scaled by 1e18
     */
    function exchangeRate() external view returns (uint256 rate) {
        if (totalSupply() == 0) {
            return 1e18; // 1:1 ratio for first deposit
        }
        return (totalUnderlyingBacked * 1e18) / totalSupply();
    }
} 
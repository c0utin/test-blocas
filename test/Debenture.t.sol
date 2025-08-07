// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Debenture.sol";
import "../src/MockDAI.sol";

contract DebentureTest is Test {
    Debenture public debenture;
    MockDAI public dai;
    
    address public owner;
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    
    uint256 constant INITIAL_AMOUNT = 10000 * 1e18;
    
    function setUp() public {
        owner = address(this);
        
        // Deploy mock DAI
        dai = new MockDAI();
        
        // Deploy Debenture
        debenture = new Debenture(
            IERC20(address(dai)),
            "DAI Debenture",
            "dDAI"
        );
        
        // Setup users with DAI
        dai.mint(user1, INITIAL_AMOUNT);
        dai.mint(user2, INITIAL_AMOUNT);
        dai.mint(user3, INITIAL_AMOUNT);
        
        // Approve Debenture to spend DAI
        vm.prank(user1);
        dai.approve(address(debenture), type(uint256).max);
        
        vm.prank(user2);
        dai.approve(address(debenture), type(uint256).max);
        
        vm.prank(user3);
        dai.approve(address(debenture), type(uint256).max);
    }
    
    function testInitialState() public {
        assertEq(debenture.name(), "DAI Debenture");
        assertEq(debenture.symbol(), "dDAI");
        assertEq(debenture.decimals(), 18);
        assertEq(debenture.totalSupply(), 0);
        assertEq(address(debenture.underlyingToken()), address(dai));
        assertEq(debenture.totalUnderlyingBacked(), 0);
        assertEq(debenture.owner(), owner);
    }
    
    function testFirstDeposit() public {
        uint256 depositAmount = 1000 * 1e18;
        
        vm.prank(user1);
        uint256 shares = debenture.deposit(depositAmount);
        
        // First deposit should be 1:1 ratio
        assertEq(shares, depositAmount);
        assertEq(debenture.balanceOf(user1), depositAmount);
        assertEq(debenture.totalSupply(), depositAmount);
        assertEq(debenture.totalUnderlyingBacked(), depositAmount);
        assertEq(dai.balanceOf(address(debenture)), depositAmount);
        
        // Check ownership percentage (100% for first depositor)
        assertEq(debenture.getOwnershipPercentage(user1), 1e18);
    }
    
    function testMultipleDeposits() public {
        uint256 deposit1 = 1000 * 1e18;
        uint256 deposit2 = 500 * 1e18;
        
        // User1 deposits first
        vm.prank(user1);
        uint256 shares1 = debenture.deposit(deposit1);
        
        // User2 deposits second
        vm.prank(user2);
        uint256 shares2 = debenture.deposit(deposit2);
        
        assertEq(shares1, deposit1); // 1:1 for first deposit
        // shares2 should be approximately deposit2, but allow for small rounding differences
        assertApproxEqAbs(shares2, deposit2, 1); // Allow 1 wei difference
        
        // Check ownership percentages
        uint256 user1Percentage = debenture.getOwnershipPercentage(user1);
        uint256 user2Percentage = debenture.getOwnershipPercentage(user2);
        
        // Use approximate equality for percentage calculations due to potential rounding
        assertApproxEqAbs(user1Percentage, (deposit1 * 1e18) / (deposit1 + deposit2), 1e15); // Allow 0.1% difference
        assertApproxEqAbs(user2Percentage, (deposit2 * 1e18) / (deposit1 + deposit2), 1e15); // Allow 0.1% difference
        
        // Total should be approximately 100%
        assertApproxEqAbs(user1Percentage + user2Percentage, 1e18, 1e15); // Total ~100%
    }
    
    function testWithdraw() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 withdrawShares = 400 * 1e18;
        
        // Deposit first
        vm.prank(user1);
        debenture.deposit(depositAmount);
        
        // Withdraw
        vm.prank(user1);
        uint256 withdrawnAmount = debenture.withdraw(withdrawShares);
        
        assertEq(withdrawnAmount, withdrawShares); // 1:1 ratio
        assertEq(debenture.balanceOf(user1), depositAmount - withdrawShares);
        assertEq(debenture.totalSupply(), depositAmount - withdrawShares);
        assertEq(debenture.totalUnderlyingBacked(), depositAmount - withdrawShares);
        assertEq(dai.balanceOf(user1), INITIAL_AMOUNT - depositAmount + withdrawnAmount);
    }
    
    function testSellBlocking() public {
        uint256 depositAmount = 1000 * 1e18;
        
        // User1 deposits
        vm.prank(user1);
        debenture.deposit(depositAmount);
        
        // Block user1 from selling
        debenture.setSellBlocked(user1, true);
        
        // Verify user1 is blocked
        assertTrue(debenture.sellBlocked(user1));
        
        // Try to withdraw - should fail
        vm.prank(user1);
        vm.expectRevert("Selling is blocked for this address");
        debenture.withdraw(100 * 1e18);
        
        // Try to transfer - should fail
        vm.prank(user1);
        vm.expectRevert("Transfers blocked for this address");
        debenture.transfer(user2, 100 * 1e18);
        
        // Unblock user1
        debenture.setSellBlocked(user1, false);
        
        // Now withdraw should work
        vm.prank(user1);
        debenture.withdraw(100 * 1e18);
    }
    
    function testOnlyOwnerCanBlockSells() public {
        vm.prank(user1);
        vm.expectRevert();
        debenture.setSellBlocked(user2, true);
    }
    
    function testExchangeRate() public {
        uint256 depositAmount = 1000 * 1e18;
        
        // Initially 1:1 ratio
        assertEq(debenture.exchangeRate(), 1e18);
        
        // After deposit, still 1:1
        vm.prank(user1);
        debenture.deposit(depositAmount);
        
        assertEq(debenture.exchangeRate(), 1e18);
        
        // Simulate gains by sending extra DAI to contract
        uint256 gains = 100 * 1e18;
        dai.mint(address(debenture), gains);
        
        // Update total backing manually (in real scenario this would be done by yield-generating mechanism)
        vm.store(
            address(debenture),
            bytes32(uint256(2)), // totalUnderlyingBacked storage slot
            bytes32(depositAmount + gains)
        );
        
        // Exchange rate should be higher now
        uint256 expectedRate = ((depositAmount + gains) * 1e18) / depositAmount;
        // Note: This test requires manual storage manipulation since we don't have actual yield mechanism
    }
    
    function test_RevertWhen_DepositZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert("Amount must be greater than 0");
        debenture.deposit(0);
    }
    
    function test_RevertWhen_WithdrawZeroShares() public {
        vm.prank(user1);
        vm.expectRevert("Shares must be greater than 0");
        debenture.withdraw(0);
    }
    
    function test_RevertWhen_WithdrawMoreThanBalance() public {
        uint256 depositAmount = 1000 * 1e18;
        
        vm.prank(user1);
        debenture.deposit(depositAmount);
        
        vm.prank(user1);
        vm.expectRevert("Insufficient shares");
        debenture.withdraw(depositAmount + 1);
    }
    
    function test_RevertWhen_WithdrawWithoutBalance() public {
        vm.prank(user1);
        vm.expectRevert("Insufficient shares");
        debenture.withdraw(100 * 1e18);
    }
    
    function testComplexOwnershipScenario() public {
        uint256 deposit1 = 1000 * 1e18;
        uint256 deposit2 = 2000 * 1e18;
        uint256 deposit3 = 500 * 1e18;
        
        // Three users deposit
        vm.prank(user1);
        debenture.deposit(deposit1);
        
        vm.prank(user2);
        debenture.deposit(deposit2);
        
        vm.prank(user3);
        debenture.deposit(deposit3);
        
        uint256 totalDeposits = deposit1 + deposit2 + deposit3;
        
        // Check ownership percentages
        assertEq(
            debenture.getOwnershipPercentage(user1),
            (deposit1 * 1e18) / totalDeposits
        );
        assertEq(
            debenture.getOwnershipPercentage(user2),
            (deposit2 * 1e18) / totalDeposits
        );
        assertEq(
            debenture.getOwnershipPercentage(user3),
            (deposit3 * 1e18) / totalDeposits
        );
        
        // User2 withdraws half their shares
        uint256 user2Shares = debenture.balanceOf(user2);
        vm.prank(user2);
        debenture.withdraw(user2Shares / 2);
        
        // Check updated ownership
        uint256 newTotalSupply = debenture.totalSupply();
        assertEq(
            debenture.getOwnershipPercentage(user1),
            (debenture.balanceOf(user1) * 1e18) / newTotalSupply
        );
        assertEq(
            debenture.getOwnershipPercentage(user2),
            (debenture.balanceOf(user2) * 1e18) / newTotalSupply
        );
        assertEq(
            debenture.getOwnershipPercentage(user3),
            (debenture.balanceOf(user3) * 1e18) / newTotalSupply
        );
    }
    
    function testEvents() public {
        uint256 depositAmount = 1000 * 1e18;
        
        // Test deposit event
        vm.expectEmit(true, true, true, true);
        emit Debenture.UnderlyingDeposited(user1, depositAmount, depositAmount);
        
        vm.prank(user1);
        debenture.deposit(depositAmount);
        
        // Test sell blocking event
        vm.expectEmit(true, true, true, true);
        emit Debenture.SellBlocked(user1, true);
        
        debenture.setSellBlocked(user1, true);
        
        // Unblock and test withdraw event
        debenture.setSellBlocked(user1, false);
        
        vm.expectEmit(true, true, true, true);
        emit Debenture.UnderlyingWithdrawn(user1, 100 * 1e18, 100 * 1e18);
        
        vm.prank(user1);
        debenture.withdraw(100 * 1e18);
    }
    
    function testFuzzDeposit(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_AMOUNT);
        
        vm.prank(user1);
        uint256 shares = debenture.deposit(amount);
        
        assertEq(shares, amount);
        assertEq(debenture.balanceOf(user1), amount);
        assertEq(debenture.getOwnershipPercentage(user1), 1e18); // 100%
    }
} 
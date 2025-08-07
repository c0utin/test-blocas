// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/WrappedDAI.sol";
import "../src/MockDAI.sol";

contract WrappedDAITest is Test {
    WrappedDAI public wrappedDAI;
    MockDAI public dai;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    uint256 constant INITIAL_AMOUNT = 1000 * 1e18;
    
    function setUp() public {
        // Deploy mock DAI
        dai = new MockDAI();
        
        // Deploy WrappedDAI
        wrappedDAI = new WrappedDAI(IERC20(address(dai)));
        
        // Setup users with DAI
        dai.mint(user1, INITIAL_AMOUNT);
        dai.mint(user2, INITIAL_AMOUNT);
        
        // Approve WrappedDAI to spend DAI
        vm.prank(user1);
        dai.approve(address(wrappedDAI), type(uint256).max);
        
        vm.prank(user2);
        dai.approve(address(wrappedDAI), type(uint256).max);
    }
    
    function testInitialState() public {
        assertEq(wrappedDAI.name(), "Wrapped DAI");
        assertEq(wrappedDAI.symbol(), "wDAI");
        assertEq(wrappedDAI.decimals(), 18);
        assertEq(wrappedDAI.totalSupply(), 0);
        assertEq(address(wrappedDAI.underlying()), address(dai));
    }
    
    function testDeposit() public {
        uint256 depositAmount = 100 * 1e18;
        
        vm.prank(user1);
        uint256 wrappedAmount = wrappedDAI.deposit(depositAmount);
        
        assertEq(wrappedAmount, depositAmount);
        assertEq(wrappedDAI.balanceOf(user1), depositAmount);
        assertEq(dai.balanceOf(user1), INITIAL_AMOUNT - depositAmount);
        assertEq(dai.balanceOf(address(wrappedDAI)), depositAmount);
    }
    
    function testWithdraw() public {
        uint256 depositAmount = 100 * 1e18;
        
        // First deposit
        vm.prank(user1);
        wrappedDAI.deposit(depositAmount);
        
        // Then withdraw
        vm.prank(user1);
        uint256 withdrawnAmount = wrappedDAI.withdraw(depositAmount);
        
        assertEq(withdrawnAmount, depositAmount);
        assertEq(wrappedDAI.balanceOf(user1), 0);
        assertEq(dai.balanceOf(user1), INITIAL_AMOUNT);
        assertEq(dai.balanceOf(address(wrappedDAI)), 0);
    }
    
    function testDepositFor() public {
        uint256 depositAmount = 100 * 1e18;
        
        vm.prank(user1);
        bool success = wrappedDAI.depositFor(user2, depositAmount);
        
        assertTrue(success);
        assertEq(wrappedDAI.balanceOf(user2), depositAmount);
        assertEq(dai.balanceOf(user1), INITIAL_AMOUNT - depositAmount);
    }
    
    function testWithdrawTo() public {
        uint256 depositAmount = 100 * 1e18;
        
        // First deposit
        vm.prank(user1);
        wrappedDAI.deposit(depositAmount);
        
        // Then withdraw to another address
        vm.prank(user1);
        bool success = wrappedDAI.withdrawTo(user2, depositAmount);
        
        assertTrue(success);
        assertEq(wrappedDAI.balanceOf(user1), 0);
        assertEq(dai.balanceOf(user2), INITIAL_AMOUNT + depositAmount);
    }
    
    function test_RevertWhen_DepositWithoutApproval() public {
        uint256 depositAmount = 100 * 1e18;
        
        // Create new user without approval
        address user3 = address(0x3);
        dai.mint(user3, INITIAL_AMOUNT);
        
        vm.prank(user3);
        vm.expectRevert();
        wrappedDAI.deposit(depositAmount); // Should fail
    }
    
    function test_RevertWhen_WithdrawMoreThanBalance() public {
        uint256 depositAmount = 100 * 1e18;
        
        vm.prank(user1);
        wrappedDAI.deposit(depositAmount);
        
        vm.prank(user1);
        vm.expectRevert();
        wrappedDAI.withdraw(depositAmount + 1); // Should fail
    }
    
    function testMultipleUsersDepositWithdraw() public {
        uint256 deposit1 = 100 * 1e18;
        uint256 deposit2 = 200 * 1e18;
        
        // User1 deposits
        vm.prank(user1);
        wrappedDAI.deposit(deposit1);
        
        // User2 deposits
        vm.prank(user2);
        wrappedDAI.deposit(deposit2);
        
        assertEq(wrappedDAI.balanceOf(user1), deposit1);
        assertEq(wrappedDAI.balanceOf(user2), deposit2);
        assertEq(wrappedDAI.totalSupply(), deposit1 + deposit2);
        assertEq(dai.balanceOf(address(wrappedDAI)), deposit1 + deposit2);
        
        // User1 withdraws half
        vm.prank(user1);
        wrappedDAI.withdraw(deposit1 / 2);
        
        assertEq(wrappedDAI.balanceOf(user1), deposit1 / 2);
        assertEq(wrappedDAI.totalSupply(), (deposit1 / 2) + deposit2);
    }
    
    function testFuzzDeposit(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_AMOUNT);
        
        vm.prank(user1);
        uint256 wrappedAmount = wrappedDAI.deposit(amount);
        
        assertEq(wrappedAmount, amount);
        assertEq(wrappedDAI.balanceOf(user1), amount);
    }
    
    function testFuzzDepositWithdraw(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_AMOUNT);
        
        // Deposit
        vm.prank(user1);
        wrappedDAI.deposit(amount);
        
        // Withdraw
        vm.prank(user1);
        uint256 withdrawnAmount = wrappedDAI.withdraw(amount);
        
        assertEq(withdrawnAmount, amount);
        assertEq(wrappedDAI.balanceOf(user1), 0);
        assertEq(dai.balanceOf(user1), INITIAL_AMOUNT);
    }
} 
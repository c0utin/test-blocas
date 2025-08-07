// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DAOGovernance.sol";
import "../src/MockDAI.sol";

contract DAOGovernanceTest is Test {
    DAOGovernance public dao;
    MockDAI public governanceToken;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    
    uint256 constant LARGE_AMOUNT = 50000 * 1e18;
    uint256 constant MEDIUM_AMOUNT = 15000 * 1e18;
    uint256 constant SMALL_AMOUNT = 5000 * 1e18;
    
    function setUp() public {
        // Deploy governance token
        governanceToken = new MockDAI();
        
        // Deploy DAO
        dao = new DAOGovernance(IERC20(address(governanceToken)));
        
        // Setup users with tokens
        governanceToken.mint(user1, LARGE_AMOUNT);
        governanceToken.mint(user2, MEDIUM_AMOUNT);
        governanceToken.mint(user3, SMALL_AMOUNT);
    }
    
    function testInitialState() public {
        assertEq(address(dao.governanceToken()), address(governanceToken));
        assertEq(dao.proposalCount(), 0);
        assertEq(dao.VOTING_PERIOD(), 7 days);
        assertEq(dao.MIN_PROPOSAL_THRESHOLD(), 1000 * 1e18);
        assertEq(dao.QUORUM_THRESHOLD(), 10000 * 1e18);
    }
    
    function testCreateProposal() public {
        string memory description = "Increase treasury allocation";
        
        vm.prank(user1);
        uint256 proposalId = dao.createProposal(description);
        
        assertEq(proposalId, 0);
        assertEq(dao.proposalCount(), 1);
        
        (
            uint256 id,
            address proposer,
            string memory desc,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 startTime,
            uint256 endTime,
            bool executed
        ) = dao.getProposal(proposalId);
        
        assertEq(id, 0);
        assertEq(proposer, user1);
        assertEq(desc, description);
        assertEq(votesFor, 0);
        assertEq(votesAgainst, 0);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + 7 days);
        assertFalse(executed);
    }
    
    function test_RevertWhen_CreateProposalInsufficientTokens() public {
        // User3 has only 5000 tokens, needs 1000 minimum (which they have)
        // Let's create a user with insufficient tokens
        address poorUser = address(0x999);
        governanceToken.mint(poorUser, 500 * 1e18); // Below threshold
        
        vm.prank(poorUser);
        vm.expectRevert("Insufficient tokens to create proposal");
        dao.createProposal("Should fail");
    }
    
    function test_RevertWhen_CreateProposalEmptyDescription() public {
        vm.prank(user1);
        vm.expectRevert("Description cannot be empty");
        dao.createProposal("");
    }
    
    function testVoteOnProposal() public {
        // Create proposal
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        // Vote for
        vm.prank(user1);
        dao.vote(proposalId, true);
        
        // Vote against
        vm.prank(user2);
        dao.vote(proposalId, false);
        
        (,,,uint256 votesFor, uint256 votesAgainst,,,) = dao.getProposal(proposalId);
        
        assertEq(votesFor, LARGE_AMOUNT);
        assertEq(votesAgainst, MEDIUM_AMOUNT);
        
        // Check vote status
        (bool hasVoted1, uint256 votingPower1) = dao.getVoteStatus(proposalId, user1);
        (bool hasVoted2, uint256 votingPower2) = dao.getVoteStatus(proposalId, user2);
        (bool hasVoted3, uint256 votingPower3) = dao.getVoteStatus(proposalId, user3);
        
        assertTrue(hasVoted1);
        assertTrue(hasVoted2);
        assertFalse(hasVoted3);
        assertEq(votingPower1, LARGE_AMOUNT);
        assertEq(votingPower2, MEDIUM_AMOUNT);
        assertEq(votingPower3, 0);
    }
    
    function test_RevertWhen_VoteTwice() public {
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        vm.prank(user1);
        dao.vote(proposalId, true);
        
        // Second vote should fail
        vm.prank(user1);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, false);
    }
    
    function test_RevertWhen_VoteOnNonexistentProposal() public {
        vm.prank(user1);
        vm.expectRevert("Proposal does not exist");
        dao.vote(999, true);
    }
    
    function test_RevertWhen_VoteWithoutTokens() public {
        address noTokenUser = address(0x888);
        
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        vm.prank(noTokenUser);
        vm.expectRevert("No voting power");
        dao.vote(proposalId, true);
    }
    
    function test_RevertWhen_VoteAfterDeadline() public {
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        // Fast forward past deadline
        vm.warp(block.timestamp + 8 days);
        
        vm.prank(user1);
        vm.expectRevert("Voting has ended");
        dao.vote(proposalId, true);
    }
    
    function testExecuteSuccessfulProposal() public {
        // Create proposal
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        // Vote for with enough votes to reach quorum and pass
        vm.prank(user1);
        dao.vote(proposalId, true); // 50000 votes
        
        vm.prank(user2);
        dao.vote(proposalId, true); // 15000 votes (total 65000, well above 10000 quorum)
        
        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);
        
        // Execute proposal
        dao.executeProposal(proposalId);
        
        (,,,,,,,bool executed) = dao.getProposal(proposalId);
        assertTrue(executed);
        
        // Check proposal state
        assertEq(dao.getProposalState(proposalId), 3); // Executed
    }
    
    function testExecuteFailedProposal() public {
        // Create proposal
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        // Vote with enough for quorum but majority against
        vm.prank(user1);
        dao.vote(proposalId, false); // 50000 against
        
        vm.prank(user2);
        dao.vote(proposalId, true); // 15000 for (total 65000 votes, but majority against)
        
        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);
        
        // Execute proposal
        dao.executeProposal(proposalId);
        
        (,,,,,,,bool executed) = dao.getProposal(proposalId);
        assertTrue(executed);
        
        // Check proposal state
        assertEq(dao.getProposalState(proposalId), 3); // Executed (but failed)
    }
    
    function test_RevertWhen_ExecuteWithoutQuorum() public {
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        // Vote but not enough for quorum (need 10000, only user3 votes with 5000)
        vm.prank(user3);
        dao.vote(proposalId, true);
        
        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);
        
        // Should fail due to insufficient quorum
        vm.expectRevert("Quorum not reached");
        dao.executeProposal(proposalId);
    }
    
    function test_RevertWhen_ExecuteBeforeDeadline() public {
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        vm.prank(user1);
        dao.vote(proposalId, true);
        
        // Try to execute before deadline
        vm.expectRevert("Voting period not ended");
        dao.executeProposal(proposalId);
    }
    
    function test_RevertWhen_ExecuteTwice() public {
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        vm.prank(user1);
        dao.vote(proposalId, true);
        
        vm.prank(user2);
        dao.vote(proposalId, true);
        
        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);
        
        // Execute once
        dao.executeProposal(proposalId);
        
        // Try to execute again
        vm.expectRevert("Proposal already executed");
        dao.executeProposal(proposalId);
    }
    
    function testProposalStates() public {
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        // Active state
        assertEq(dao.getProposalState(proposalId), 0);
        
        // Vote enough for quorum and success
        vm.prank(user1);
        dao.vote(proposalId, true);
        
        vm.prank(user2);
        dao.vote(proposalId, true);
        
        // Still active during voting period
        assertEq(dao.getProposalState(proposalId), 0);
        
        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);
        
        // Should be succeeded
        assertEq(dao.getProposalState(proposalId), 1);
        
        // Execute
        dao.executeProposal(proposalId);
        
        // Should be executed
        assertEq(dao.getProposalState(proposalId), 3);
    }
    
    function testProposalFailedState() public {
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        // Vote with majority against
        vm.prank(user1);
        dao.vote(proposalId, false);
        
        vm.prank(user2);
        dao.vote(proposalId, true);
        
        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);
        
        // Should be failed
        assertEq(dao.getProposalState(proposalId), 2);
    }
    
    function testProposalFailedNoQuorum() public {
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        // Vote but insufficient for quorum
        vm.prank(user3);
        dao.vote(proposalId, true); // Only 5000 votes, need 10000
        
        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);
        
        // Should be failed due to no quorum
        assertEq(dao.getProposalState(proposalId), 2);
    }
    
    function testMultipleProposals() public {
        // Create multiple proposals
        vm.prank(user1);
        uint256 proposal1 = dao.createProposal("Proposal 1");
        
        vm.prank(user2);
        uint256 proposal2 = dao.createProposal("Proposal 2");
        
        assertEq(proposal1, 0);
        assertEq(proposal2, 1);
        assertEq(dao.proposalCount(), 2);
        
        // Vote on different proposals
        vm.prank(user1);
        dao.vote(proposal1, true);
        
        vm.prank(user1);
        dao.vote(proposal2, false);
        
        // Check votes are separate
        (,,,uint256 votes1For, uint256 votes1Against,,,) = dao.getProposal(proposal1);
        (,,,uint256 votes2For, uint256 votes2Against,,,) = dao.getProposal(proposal2);
        
        assertEq(votes1For, LARGE_AMOUNT);
        assertEq(votes1Against, 0);
        assertEq(votes2For, 0);
        assertEq(votes2Against, LARGE_AMOUNT);
    }
    
    function testEvents() public {
        // Test proposal created event
        vm.expectEmit(true, true, true, true);
        emit DAOGovernance.ProposalCreated(
            0,
            user1,
            "Test proposal",
            block.timestamp,
            block.timestamp + 7 days
        );
        
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Test proposal");
        
        // Test vote cast event
        vm.expectEmit(true, true, true, true);
        emit DAOGovernance.VoteCast(proposalId, user1, true, LARGE_AMOUNT);
        
        vm.prank(user1);
        dao.vote(proposalId, true);
        
        // Add more votes for quorum and execution
        vm.prank(user2);
        dao.vote(proposalId, true);
        
        vm.warp(block.timestamp + 8 days);
        
        // Test proposal executed event
        vm.expectEmit(true, true, true, true);
        emit DAOGovernance.ProposalExecuted(proposalId, true);
        
        dao.executeProposal(proposalId);
    }
    
    function testFuzzVoting(uint256 tokenAmount, bool support) public {
        vm.assume(tokenAmount > 0 && tokenAmount <= 1000000 * 1e18);
        
        address fuzzer = address(0x999);
        governanceToken.mint(fuzzer, tokenAmount);
        
        vm.prank(user1);
        uint256 proposalId = dao.createProposal("Fuzz test proposal");
        
        vm.prank(fuzzer);
        dao.vote(proposalId, support);
        
        (,,,uint256 votesFor, uint256 votesAgainst,,,) = dao.getProposal(proposalId);
        
        if (support) {
            assertEq(votesFor, tokenAmount);
            assertEq(votesAgainst, 0);
        } else {
            assertEq(votesFor, 0);
            assertEq(votesAgainst, tokenAmount);
        }
    }
} 
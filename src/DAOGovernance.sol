// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title DAOGovernance
 * @notice Simple DAO governance contract for token holders to vote on proposals
 * @dev Allows creating proposals and voting with token-weighted voting power
 */
contract DAOGovernance is ReentrancyGuard {
    IERC20 public immutable governanceToken;
    
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) votingPower; // Snapshot of voting power
    }
    
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    
    // Governance parameters
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000 * 1e18; // Minimum tokens to create proposal
    uint256 public constant QUORUM_THRESHOLD = 10000 * 1e18; // Minimum total votes for validity
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 startTime,
        uint256 endTime
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votingPower
    );
    
    event ProposalExecuted(uint256 indexed proposalId, bool passed);
    
    constructor(IERC20 _governanceToken) {
        governanceToken = _governanceToken;
    }
    
    /**
     * @notice Create a new proposal
     * @param description Description of the proposal
     * @return proposalId ID of the created proposal
     */
    function createProposal(string memory description) external returns (uint256 proposalId) {
        require(
            governanceToken.balanceOf(msg.sender) >= MIN_PROPOSAL_THRESHOLD,
            "Insufficient tokens to create proposal"
        );
        require(bytes(description).length > 0, "Description cannot be empty");
        
        proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + VOTING_PERIOD;
        proposal.executed = false;
        
        emit ProposalCreated(
            proposalId,
            msg.sender,
            description,
            proposal.startTime,
            proposal.endTime
        );
        
        return proposalId;
    }
    
    /**
     * @notice Vote on a proposal
     * @param proposalId ID of the proposal to vote on
     * @param support True for yes, false for no
     */
    function vote(uint256 proposalId, bool support) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposalId < proposalCount, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime, "Voting has not started");
        require(block.timestamp <= proposal.endTime, "Voting has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        
        uint256 votingPower = governanceToken.balanceOf(msg.sender);
        require(votingPower > 0, "No voting power");
        
        proposal.hasVoted[msg.sender] = true;
        proposal.votingPower[msg.sender] = votingPower;
        
        if (support) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }
        
        emit VoteCast(proposalId, msg.sender, support, votingPower);
    }
    
    /**
     * @notice Execute a proposal after voting period ends
     * @param proposalId ID of the proposal to execute
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposalId < proposalCount, "Proposal does not exist");
        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        require(totalVotes >= QUORUM_THRESHOLD, "Quorum not reached");
        
        proposal.executed = true;
        bool passed = proposal.votesFor > proposal.votesAgainst;
        
        emit ProposalExecuted(proposalId, passed);
    }
    
    /**
     * @notice Get proposal details
     * @param proposalId ID of the proposal
     * @return id Proposal ID
     * @return proposer Address of proposer
     * @return description Proposal description
     * @return votesFor Votes in favor
     * @return votesAgainst Votes against
     * @return startTime Voting start time
     * @return endTime Voting end time
     * @return executed Whether proposal has been executed
     */
    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        address proposer,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 startTime,
        uint256 endTime,
        bool executed
    ) {
        require(proposalId < proposalCount, "Proposal does not exist");
        
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.startTime,
            proposal.endTime,
            proposal.executed
        );
    }
    
    /**
     * @notice Check if an address has voted on a proposal
     * @param proposalId ID of the proposal
     * @param voter Address to check
     * @return hasVoted Whether the address has voted
     * @return votingPower Voting power used (0 if not voted)
     */
    function getVoteStatus(uint256 proposalId, address voter) external view returns (
        bool hasVoted,
        uint256 votingPower
    ) {
        require(proposalId < proposalCount, "Proposal does not exist");
        
        Proposal storage proposal = proposals[proposalId];
        return (proposal.hasVoted[voter], proposal.votingPower[voter]);
    }
    
    /**
     * @notice Get current proposal state
     * @param proposalId ID of the proposal
     * @return state Current state (0: Active, 1: Succeeded, 2: Failed, 3: Executed)
     */
    function getProposalState(uint256 proposalId) external view returns (uint256 state) {
        require(proposalId < proposalCount, "Proposal does not exist");
        
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.executed) {
            return 3; // Executed
        }
        
        if (block.timestamp <= proposal.endTime) {
            return 0; // Active
        }
        
        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        if (totalVotes < QUORUM_THRESHOLD) {
            return 2; // Failed (no quorum)
        }
        
        if (proposal.votesFor > proposal.votesAgainst) {
            return 1; // Succeeded
        } else {
            return 2; // Failed
        }
    }
} 
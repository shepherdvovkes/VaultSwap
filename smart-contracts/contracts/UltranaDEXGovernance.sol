// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IUltranaDEXGovernance.sol";
import "./interfaces/IUltranaDEXToken.sol";
import "./security/MEVProtection.sol";

/**
 * @title UltranaDEXGovernance
 * @dev Governance contract for Ultrana DEX DAO
 * @notice This contract handles proposal creation, voting, and execution
 */
contract UltranaDEXGovernance is IUltranaDEXGovernance, ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;
    
    // State variables
    address public override token;
    address public override securityManager;
    address public override mevProtection;
    
    uint256 public override votingPeriod;
    uint256 public override executionDelay;
    uint256 public override proposalThreshold;
    uint256 public override quorumThreshold;
    uint256 public override supermajorityThreshold;
    
    uint256 public override proposalCount;
    mapping(uint256 => Proposal) public override proposals;
    mapping(uint256 => mapping(address => bool)) public override hasVoted;
    mapping(address => uint256) public override votingPower;
    mapping(address => uint256) public override lastVoteTime;
    
    // Security features
    mapping(address => bool) public override isAuthorized;
    mapping(address => uint256) public override voteCooldown;
    uint256 public override maxProposalDescriptionLength;
    uint256 public override maxProposalTitleLength;
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        string description,
        uint256 startTime,
        uint256 endTime
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 support,
        uint256 votingPower
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event VotingPowerUpdated(address indexed voter, uint256 votingPower);
    event SecurityManagerChanged(address indexed securityManager);
    event MEVProtectionChanged(address indexed mevProtection);
    event AuthorizationChanged(address indexed account, bool authorized);
    event VoteCooldownChanged(address indexed account, uint256 cooldown);
    event ThresholdsUpdated(
        uint256 proposalThreshold,
        uint256 quorumThreshold,
        uint256 supermajorityThreshold
    );
    
    // Modifiers
    modifier onlyAuthorized() {
        require(isAuthorized[msg.sender] || msg.sender == owner(), "UltranaDEXGovernance: FORBIDDEN");
        _;
    }
    
    modifier onlySecurityManager() {
        require(msg.sender == securityManager, "UltranaDEXGovernance: FORBIDDEN");
        _;
    }
    
    modifier voteCooldownCheck() {
        require(block.timestamp >= lastVoteTime[msg.sender] + voteCooldown[msg.sender], "UltranaDEXGovernance: VOTE_COOLDOWN");
        _;
    }
    
    constructor(
        address _token,
        uint256 _votingPeriod,
        uint256 _executionDelay,
        uint256 _proposalThreshold,
        uint256 _quorumThreshold,
        uint256 _supermajorityThreshold
    ) {
        require(_token != address(0), "UltranaDEXGovernance: ZERO_ADDRESS");
        require(_votingPeriod > 0, "UltranaDEXGovernance: INVALID_VOTING_PERIOD");
        require(_executionDelay > 0, "UltranaDEXGovernance: INVALID_EXECUTION_DELAY");
        require(_proposalThreshold > 0, "UltranaDEXGovernance: INVALID_PROPOSAL_THRESHOLD");
        require(_quorumThreshold > 0 && _quorumThreshold <= 100, "UltranaDEXGovernance: INVALID_QUORUM_THRESHOLD");
        require(_supermajorityThreshold > 0 && _supermajorityThreshold <= 100, "UltranaDEXGovernance: INVALID_SUPERMAJORITY_THRESHOLD");
        
        token = _token;
        votingPeriod = _votingPeriod;
        executionDelay = _executionDelay;
        proposalThreshold = _proposalThreshold;
        quorumThreshold = _quorumThreshold;
        supermajorityThreshold = _supermajorityThreshold;
        
        maxProposalDescriptionLength = 10000;
        maxProposalTitleLength = 200;
    }
    
    /**
     * @dev Create a new proposal
     * @param title Proposal title
     * @param description Proposal description
     * @param targets Array of target addresses for calls
     * @param values Array of ETH values for calls
     * @param calldatas Array of calldata for calls
     * @return proposalId The ID of the created proposal
     */
    function propose(
        string calldata title,
        string calldata description,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external override nonReentrant whenNotPaused onlyAuthorized returns (uint256 proposalId) {
        require(bytes(title).length <= maxProposalTitleLength, "UltranaDEXGovernance: TITLE_TOO_LONG");
        require(bytes(description).length <= maxProposalDescriptionLength, "UltranaDEXGovernance: DESCRIPTION_TOO_LONG");
        require(targets.length == values.length && targets.length == calldatas.length, "UltranaDEXGovernance: ARRAY_LENGTH_MISMATCH");
        require(targets.length > 0, "UltranaDEXGovernance: EMPTY_PROPOSAL");
        require(targets.length <= 10, "UltranaDEXGovernance: TOO_MANY_ACTIONS");
        
        uint256 proposerVotingPower = getVotingPower(msg.sender);
        require(proposerVotingPower >= proposalThreshold, "UltranaDEXGovernance: INSUFFICIENT_VOTING_POWER");
        
        // Check MEV protection
        if (mevProtection != address(0)) {
            require(IMEVProtection(mevProtection).checkMEVProtection(msg.sender, targets, values), "UltranaDEXGovernance: MEV_PROTECTION_FAILED");
        }
        
        proposalId = proposalCount++;
        uint256 startTime = block.timestamp + executionDelay;
        uint256 endTime = startTime + votingPeriod;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: title,
            description: description,
            targets: targets,
            values: values,
            calldatas: calldatas,
            startTime: startTime,
            endTime: endTime,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false,
            cancelled: false
        });
        
        emit ProposalCreated(proposalId, msg.sender, title, description, startTime, endTime);
    }
    
    /**
     * @dev Cast a vote on a proposal
     * @param proposalId The ID of the proposal to vote on
     * @param support The vote (0 = Against, 1 = For, 2 = Abstain)
     */
    function castVote(uint256 proposalId, uint8 support) external override nonReentrant whenNotPaused onlyAuthorized voteCooldownCheck {
        require(proposalId < proposalCount, "UltranaDEXGovernance: INVALID_PROPOSAL_ID");
        require(support <= 2, "UltranaDEXGovernance: INVALID_VOTE");
        require(!hasVoted[proposalId][msg.sender], "UltranaDEXGovernance: ALREADY_VOTED");
        
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "UltranaDEXGovernance: VOTING_NOT_STARTED");
        require(block.timestamp <= proposal.endTime, "UltranaDEXGovernance: VOTING_ENDED");
        require(!proposal.executed, "UltranaDEXGovernance: PROPOSAL_EXECUTED");
        require(!proposal.cancelled, "UltranaDEXGovernance: PROPOSAL_CANCELLED");
        
        uint256 voterVotingPower = getVotingPower(msg.sender);
        require(voterVotingPower > 0, "UltranaDEXGovernance: NO_VOTING_POWER");
        
        hasVoted[proposalId][msg.sender] = true;
        lastVoteTime[msg.sender] = block.timestamp;
        
        if (support == 0) {
            proposal.againstVotes += voterVotingPower;
        } else if (support == 1) {
            proposal.forVotes += voterVotingPower;
        } else if (support == 2) {
            proposal.abstainVotes += voterVotingPower;
        }
        
        emit VoteCast(proposalId, msg.sender, support, voterVotingPower);
    }
    
    /**
     * @dev Execute a proposal
     * @param proposalId The ID of the proposal to execute
     */
    function execute(uint256 proposalId) external override nonReentrant whenNotPaused onlyAuthorized {
        require(proposalId < proposalCount, "UltranaDEXGovernance: INVALID_PROPOSAL_ID");
        
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "UltranaDEXGovernance: VOTING_NOT_ENDED");
        require(!proposal.executed, "UltranaDEXGovernance: PROPOSAL_EXECUTED");
        require(!proposal.cancelled, "UltranaDEXGovernance: PROPOSAL_CANCELLED");
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        require(totalVotes >= (IERC20(token).totalSupply() * quorumThreshold) / 100, "UltranaDEXGovernance: QUORUM_NOT_MET");
        
        bool isSupermajority = proposal.forVotes >= (totalVotes * supermajorityThreshold) / 100;
        bool isSimpleMajority = proposal.forVotes > proposal.againstVotes;
        
        require(isSupermajority || isSimpleMajority, "UltranaDEXGovernance: PROPOSAL_NOT_PASSED");
        
        proposal.executed = true;
        
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, bytes memory returnData) = proposal.targets[i].call{value: proposal.values[i]}(proposal.calldatas[i]);
            require(success, "UltranaDEXGovernance: EXECUTION_FAILED");
        }
        
        emit ProposalExecuted(proposalId);
    }
    
    /**
     * @dev Cancel a proposal
     * @param proposalId The ID of the proposal to cancel
     */
    function cancel(uint256 proposalId) external override nonReentrant whenNotPaused {
        require(proposalId < proposalCount, "UltranaDEXGovernance: INVALID_PROPOSAL_ID");
        
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer || msg.sender == owner(), "UltranaDEXGovernance: FORBIDDEN");
        require(!proposal.executed, "UltranaDEXGovernance: PROPOSAL_EXECUTED");
        require(!proposal.cancelled, "UltranaDEXGovernance: PROPOSAL_CANCELLED");
        
        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }
    
    /**
     * @dev Get voting power for an address
     * @param account Address to get voting power for
     * @return votingPower The voting power of the address
     */
    function getVotingPower(address account) public view override returns (uint256 votingPower) {
        return IERC20(token).balanceOf(account);
    }
    
    /**
     * @dev Get proposal state
     * @param proposalId The ID of the proposal
     * @return state The state of the proposal
     */
    function getProposalState(uint256 proposalId) external view override returns (ProposalState state) {
        require(proposalId < proposalCount, "UltranaDEXGovernance: INVALID_PROPOSAL_ID");
        
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp < proposal.startTime) {
            return ProposalState.Pending;
        } else if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        } else {
            uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
            uint256 quorumRequired = (IERC20(token).totalSupply() * quorumThreshold) / 100;
            
            if (totalVotes < quorumRequired) {
                return ProposalState.Failed;
            } else if (proposal.forVotes > proposal.againstVotes) {
                return ProposalState.Succeeded;
            } else {
                return ProposalState.Failed;
            }
        }
    }
    
    /**
     * @dev Set security manager
     * @param _securityManager New security manager address
     */
    function setSecurityManager(address _securityManager) external override onlyOwner {
        require(_securityManager != address(0), "UltranaDEXGovernance: ZERO_ADDRESS");
        securityManager = _securityManager;
        emit SecurityManagerChanged(_securityManager);
    }
    
    /**
     * @dev Set MEV protection contract
     * @param _mevProtection New MEV protection address
     */
    function setMEVProtection(address _mevProtection) external override onlyOwner {
        mevProtection = _mevProtection;
        emit MEVProtectionChanged(_mevProtection);
    }
    
    /**
     * @dev Set authorization for an address
     * @param account Address to authorize/deauthorize
     * @param authorized Authorization status
     */
    function setAuthorization(address account, bool authorized) external override onlySecurityManager {
        require(account != address(0), "UltranaDEXGovernance: ZERO_ADDRESS");
        isAuthorized[account] = authorized;
        emit AuthorizationChanged(account, authorized);
    }
    
    /**
     * @dev Set vote cooldown for an address
     * @param account Address to set cooldown for
     * @param cooldown Cooldown period in seconds
     */
    function setVoteCooldown(address account, uint256 cooldown) external override onlySecurityManager {
        require(account != address(0), "UltranaDEXGovernance: ZERO_ADDRESS");
        voteCooldown[account] = cooldown;
        emit VoteCooldownChanged(account, cooldown);
    }
    
    /**
     * @dev Update governance thresholds
     * @param _proposalThreshold New proposal threshold
     * @param _quorumThreshold New quorum threshold
     * @param _supermajorityThreshold New supermajority threshold
     */
    function updateThresholds(
        uint256 _proposalThreshold,
        uint256 _quorumThreshold,
        uint256 _supermajorityThreshold
    ) external override onlyOwner {
        require(_proposalThreshold > 0, "UltranaDEXGovernance: INVALID_PROPOSAL_THRESHOLD");
        require(_quorumThreshold > 0 && _quorumThreshold <= 100, "UltranaDEXGovernance: INVALID_QUORUM_THRESHOLD");
        require(_supermajorityThreshold > 0 && _supermajorityThreshold <= 100, "UltranaDEXGovernance: INVALID_SUPERMAJORITY_THRESHOLD");
        
        proposalThreshold = _proposalThreshold;
        quorumThreshold = _quorumThreshold;
        supermajorityThreshold = _supermajorityThreshold;
        
        emit ThresholdsUpdated(_proposalThreshold, _quorumThreshold, _supermajorityThreshold);
    }
    
    /**
     * @dev Pause the governance (emergency function)
     */
    function pause() external override onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the governance
     */
    function unpause() external override onlyOwner {
        _unpause();
    }
}

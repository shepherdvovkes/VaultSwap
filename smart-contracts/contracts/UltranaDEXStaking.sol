// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./interfaces/IUltranaDEXStaking.sol";
import "./interfaces/IUltranaDEXToken.sol";
import "./security/MEVProtection.sol";

/**
 * @title UltranaDEXStaking
 * @dev Staking contract for Ultrana DEX tokens
 * @notice This contract handles token staking, rewards distribution, and farming
 */
contract UltranaDEXStaking is IUltranaDEXStaking, ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;
    
    // State variables
    address public override stakingToken;
    address public override rewardToken;
    address public override securityManager;
    address public override mevProtection;
    
    uint256 public override totalStaked;
    uint256 public override totalRewards;
    uint256 public override rewardRate;
    uint256 public override periodFinish;
    uint256 public override lastUpdateTime;
    uint256 public override rewardPerTokenStored;
    
    // Staking pools
    mapping(uint256 => StakingPool) public override stakingPools;
    uint256 public override poolCount;
    
    // User staking data
    mapping(address => mapping(uint256 => UserStake)) public override userStakes;
    mapping(address => uint256) public override userRewardPerTokenPaid;
    mapping(address => uint256) public override rewards;
    
    // Security features
    mapping(address => bool) public override isAuthorized;
    mapping(address => uint256) public override lastStakeTime;
    mapping(address => uint256) public override stakeCooldown;
    uint256 public override maxStakeAmount;
    uint256 public override minStakeAmount;
    
    // Events
    event Staked(address indexed user, uint256 indexed poolId, uint256 amount, uint256 duration);
    event Unstaked(address indexed user, uint256 indexed poolId, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event PoolCreated(uint256 indexed poolId, uint256 duration, uint256 apy, uint256 maxStake);
    event PoolUpdated(uint256 indexed poolId, uint256 apy, uint256 maxStake);
    event SecurityManagerChanged(address indexed securityManager);
    event MEVProtectionChanged(address indexed mevProtection);
    event AuthorizationChanged(address indexed account, bool authorized);
    event StakeCooldownChanged(address indexed account, uint256 cooldown);
    event MaxStakeAmountChanged(uint256 maxStakeAmount);
    event MinStakeAmountChanged(uint256 minStakeAmount);
    
    // Modifiers
    modifier onlyAuthorized() {
        require(isAuthorized[msg.sender] || msg.sender == owner(), "UltranaDEXStaking: FORBIDDEN");
        _;
    }
    
    modifier onlySecurityManager() {
        require(msg.sender == securityManager, "UltranaDEXStaking: FORBIDDEN");
        _;
    }
    
    modifier stakeCooldownCheck() {
        require(block.timestamp >= lastStakeTime[msg.sender] + stakeCooldown[msg.sender], "UltranaDEXStaking: STAKE_COOLDOWN");
        _;
    }
    
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }
    
    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRate
    ) {
        require(_stakingToken != address(0), "UltranaDEXStaking: ZERO_ADDRESS");
        require(_rewardToken != address(0), "UltranaDEXStaking: ZERO_ADDRESS");
        require(_rewardRate > 0, "UltranaDEXStaking: INVALID_REWARD_RATE");
        
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        rewardRate = _rewardRate;
        periodFinish = block.timestamp + 365 days; // 1 year default period
        
        maxStakeAmount = type(uint256).max;
        minStakeAmount = 0;
    }
    
    /**
     * @dev Stake tokens in a specific pool
     * @param poolId The ID of the staking pool
     * @param amount Amount of tokens to stake
     */
    function stake(uint256 poolId, uint256 amount) external override nonReentrant whenNotPaused onlyAuthorized stakeCooldownCheck updateReward(msg.sender) {
        require(poolId < poolCount, "UltranaDEXStaking: INVALID_POOL_ID");
        require(amount >= minStakeAmount, "UltranaDEXStaking: BELOW_MIN_STAKE");
        require(amount <= maxStakeAmount, "UltranaDEXStaking: EXCEEDS_MAX_STAKE");
        
        StakingPool storage pool = stakingPools[poolId];
        require(pool.isActive, "UltranaDEXStaking: POOL_INACTIVE");
        require(amount <= pool.maxStake, "UltranaDEXStaking: EXCEEDS_POOL_MAX_STAKE");
        
        // Check MEV protection
        if (mevProtection != address(0)) {
            require(IMEVProtection(mevProtection).checkMEVProtection(msg.sender, address(this), amount), "UltranaDEXStaking: MEV_PROTECTION_FAILED");
        }
        
        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        
        UserStake storage userStake = userStakes[msg.sender][poolId];
        userStake.amount += amount;
        userStake.stakeTime = block.timestamp;
        userStake.duration = pool.duration;
        
        totalStaked += amount;
        pool.totalStaked += amount;
        
        lastStakeTime[msg.sender] = block.timestamp;
        
        emit Staked(msg.sender, poolId, amount, pool.duration);
    }
    
    /**
     * @dev Unstake tokens from a specific pool
     * @param poolId The ID of the staking pool
     * @param amount Amount of tokens to unstake
     */
    function unstake(uint256 poolId, uint256 amount) external override nonReentrant whenNotPaused onlyAuthorized updateReward(msg.sender) {
        require(poolId < poolCount, "UltranaDEXStaking: INVALID_POOL_ID");
        
        UserStake storage userStake = userStakes[msg.sender][poolId];
        require(userStake.amount >= amount, "UltranaDEXStaking: INSUFFICIENT_STAKE");
        require(block.timestamp >= userStake.stakeTime + userStake.duration, "UltranaDEXStaking: STAKE_NOT_MATURED");
        
        userStake.amount -= amount;
        totalStaked -= amount;
        stakingPools[poolId].totalStaked -= amount;
        
        IERC20(stakingToken).safeTransfer(msg.sender, amount);
        
        emit Unstaked(msg.sender, poolId, amount);
    }
    
    /**
     * @dev Claim rewards
     */
    function claimRewards() external override nonReentrant whenNotPaused onlyAuthorized updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "UltranaDEXStaking: NO_REWARDS");
        
        rewards[msg.sender] = 0;
        IERC20(rewardToken).safeTransfer(msg.sender, reward);
        
        emit RewardPaid(msg.sender, reward);
    }
    
    /**
     * @dev Create a new staking pool
     * @param duration Staking duration in seconds
     * @param apy Annual percentage yield (in basis points)
     * @param maxStake Maximum stake amount for this pool
     */
    function createPool(
        uint256 duration,
        uint256 apy,
        uint256 maxStake
    ) external override onlyOwner returns (uint256 poolId) {
        require(duration > 0, "UltranaDEXStaking: INVALID_DURATION");
        require(apy > 0, "UltranaDEXStaking: INVALID_APY");
        require(maxStake > 0, "UltranaDEXStaking: INVALID_MAX_STAKE");
        
        poolId = poolCount++;
        stakingPools[poolId] = StakingPool({
            id: poolId,
            duration: duration,
            apy: apy,
            maxStake: maxStake,
            totalStaked: 0,
            isActive: true
        });
        
        emit PoolCreated(poolId, duration, apy, maxStake);
    }
    
    /**
     * @dev Update a staking pool
     * @param poolId The ID of the pool to update
     * @param apy New APY for the pool
     * @param maxStake New maximum stake amount
     */
    function updatePool(
        uint256 poolId,
        uint256 apy,
        uint256 maxStake
    ) external override onlyOwner {
        require(poolId < poolCount, "UltranaDEXStaking: INVALID_POOL_ID");
        require(apy > 0, "UltranaDEXStaking: INVALID_APY");
        require(maxStake > 0, "UltranaDEXStaking: INVALID_MAX_STAKE");
        
        StakingPool storage pool = stakingPools[poolId];
        pool.apy = apy;
        pool.maxStake = maxStake;
        
        emit PoolUpdated(poolId, apy, maxStake);
    }
    
    /**
     * @dev Set pool active status
     * @param poolId The ID of the pool
     * @param isActive Active status
     */
    function setPoolActive(uint256 poolId, bool isActive) external override onlyOwner {
        require(poolId < poolCount, "UltranaDEXStaking: INVALID_POOL_ID");
        stakingPools[poolId].isActive = isActive;
    }
    
    /**
     * @dev Get the last time reward was applicable
     * @return timestamp The last time reward was applicable
     */
    function lastTimeRewardApplicable() public view override returns (uint256 timestamp) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }
    
    /**
     * @dev Get the reward per token
     * @return rewardPerToken The reward per token
     */
    function rewardPerToken() public view override returns (uint256 rewardPerToken) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalStaked;
    }
    
    /**
     * @dev Get the earned rewards for an account
     * @param account Account to get rewards for
     * @return earned The earned rewards
     */
    function earned(address account) public view override returns (uint256 earned) {
        return (getUserTotalStake(account) * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account];
    }
    
    /**
     * @dev Get the total stake for a user across all pools
     * @param user User address
     * @return totalStake The total stake amount
     */
    function getUserTotalStake(address user) public view override returns (uint256 totalStake) {
        for (uint256 i = 0; i < poolCount; i++) {
            totalStake += userStakes[user][i].amount;
        }
    }
    
    /**
     * @dev Get the stake for a user in a specific pool
     * @param user User address
     * @param poolId Pool ID
     * @return stake The stake amount
     */
    function getUserStake(address user, uint256 poolId) external view override returns (uint256 stake) {
        return userStakes[user][poolId].amount;
    }
    
    /**
     * @dev Set security manager
     * @param _securityManager New security manager address
     */
    function setSecurityManager(address _securityManager) external override onlyOwner {
        require(_securityManager != address(0), "UltranaDEXStaking: ZERO_ADDRESS");
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
        require(account != address(0), "UltranaDEXStaking: ZERO_ADDRESS");
        isAuthorized[account] = authorized;
        emit AuthorizationChanged(account, authorized);
    }
    
    /**
     * @dev Set stake cooldown for an address
     * @param account Address to set cooldown for
     * @param cooldown Cooldown period in seconds
     */
    function setStakeCooldown(address account, uint256 cooldown) external override onlySecurityManager {
        require(account != address(0), "UltranaDEXStaking: ZERO_ADDRESS");
        stakeCooldown[account] = cooldown;
        emit StakeCooldownChanged(account, cooldown);
    }
    
    /**
     * @dev Set maximum stake amount
     * @param _maxStakeAmount Maximum stake amount
     */
    function setMaxStakeAmount(uint256 _maxStakeAmount) external override onlySecurityManager {
        maxStakeAmount = _maxStakeAmount;
        emit MaxStakeAmountChanged(_maxStakeAmount);
    }
    
    /**
     * @dev Set minimum stake amount
     * @param _minStakeAmount Minimum stake amount
     */
    function setMinStakeAmount(uint256 _minStakeAmount) external override onlySecurityManager {
        minStakeAmount = _minStakeAmount;
        emit MinStakeAmountChanged(_minStakeAmount);
    }
    
    /**
     * @dev Pause the staking (emergency function)
     */
    function pause() external override onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the staking
     */
    function unpause() external override onlyOwner {
        _unpause();
    }
}

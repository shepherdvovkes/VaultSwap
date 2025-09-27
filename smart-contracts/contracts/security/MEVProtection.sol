// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IMEVProtection.sol";

/**
 * @title MEVProtection
 * @dev MEV protection contract for Ultrana DEX
 * @notice This contract implements various MEV protection mechanisms
 */
contract MEVProtection is IMEVProtection, ReentrancyGuard, Pausable, Ownable {
    // State variables
    address public override securityManager;
    address public override oracle;
    
    // MEV protection parameters
    uint256 public override maxSlippage;
    uint256 public override maxPriceImpact;
    uint256 public override minLiquidity;
    uint256 public override maxGasPrice;
    
    // Attack detection
    mapping(address => uint256) public override lastTradeTime;
    mapping(address => uint256) public override tradeCount;
    mapping(address => uint256) public override suspiciousActivity;
    
    // Blacklisted addresses
    mapping(address => bool) public override isBlacklisted;
    
    // Events
    event MEVAttackDetected(address indexed attacker, string attackType, uint256 severity);
    event BlacklistUpdated(address indexed account, bool blacklisted);
    event SecurityManagerChanged(address indexed securityManager);
    event OracleChanged(address indexed oracle);
    event ParametersUpdated(
        uint256 maxSlippage,
        uint256 maxPriceImpact,
        uint256 minLiquidity,
        uint256 maxGasPrice
    );
    
    // Modifiers
    modifier onlySecurityManager() {
        require(msg.sender == securityManager, "MEVProtection: FORBIDDEN");
        _;
    }
    
    constructor(
        address _securityManager,
        address _oracle,
        uint256 _maxSlippage,
        uint256 _maxPriceImpact,
        uint256 _minLiquidity,
        uint256 _maxGasPrice
    ) {
        require(_securityManager != address(0), "MEVProtection: ZERO_ADDRESS");
        require(_oracle != address(0), "MEVProtection: ZERO_ADDRESS");
        
        securityManager = _securityManager;
        oracle = _oracle;
        maxSlippage = _maxSlippage;
        maxPriceImpact = _maxPriceImpact;
        minLiquidity = _minLiquidity;
        maxGasPrice = _maxGasPrice;
    }
    
    /**
     * @dev Check MEV protection for a swap
     * @param user User address
     * @param path Swap path
     * @param amounts Swap amounts
     * @return protected Whether the swap is protected
     */
    function checkMEVProtection(
        address user,
        address[] calldata path,
        uint256[] calldata amounts
    ) external view override returns (bool protected) {
        require(!isBlacklisted[user], "MEVProtection: BLACKLISTED_USER");
        require(tx.gasprice <= maxGasPrice, "MEVProtection: HIGH_GAS_PRICE");
        
        // Check for sandwich attack
        if (isSandwichAttack(user, path, amounts)) {
            return false;
        }
        
        // Check for front-running
        if (isFrontRunning(user, path, amounts)) {
            return false;
        }
        
        // Check for back-running
        if (isBackRunning(user, path, amounts)) {
            return false;
        }
        
        // Check for liquidity manipulation
        if (isLiquidityManipulation(user, path, amounts)) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @dev Check MEV protection for a governance proposal
     * @param proposer Proposer address
     * @param targets Proposal targets
     * @param values Proposal values
     * @return protected Whether the proposal is protected
     */
    function checkMEVProtection(
        address proposer,
        address[] calldata targets,
        uint256[] calldata values
    ) external view override returns (bool protected) {
        require(!isBlacklisted[proposer], "MEVProtection: BLACKLISTED_PROPOSER");
        require(tx.gasprice <= maxGasPrice, "MEVProtection: HIGH_GAS_PRICE");
        
        // Check for governance manipulation
        if (isGovernanceManipulation(proposer, targets, values)) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @dev Check MEV protection for a staking operation
     * @param user User address
     * @param target Target contract
     * @param amount Staking amount
     * @return protected Whether the staking is protected
     */
    function checkMEVProtection(
        address user,
        address target,
        uint256 amount
    ) external view override returns (bool protected) {
        require(!isBlacklisted[user], "MEVProtection: BLACKLISTED_USER");
        require(tx.gasprice <= maxGasPrice, "MEVProtection: HIGH_GAS_PRICE");
        
        // Check for staking manipulation
        if (isStakingManipulation(user, target, amount)) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @dev Detect sandwich attack
     * @param user User address
     * @param path Swap path
     * @param amounts Swap amounts
     * @return isAttack Whether it's a sandwich attack
     */
    function isSandwichAttack(
        address user,
        address[] calldata path,
        uint256[] calldata amounts
    ) public view override returns (bool isAttack) {
        // Check if user has made multiple trades in quick succession
        if (block.timestamp - lastTradeTime[user] < 60) { // Within 1 minute
            tradeCount[user]++;
            if (tradeCount[user] > 3) { // More than 3 trades in 1 minute
                return true;
            }
        }
        
        // Check for price manipulation
        if (amounts.length >= 2) {
            uint256 priceImpact = calculatePriceImpact(path, amounts);
            if (priceImpact > maxPriceImpact) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @dev Detect front-running
     * @param user User address
     * @param path Swap path
     * @param amounts Swap amounts
     * @return isAttack Whether it's front-running
     */
    function isFrontRunning(
        address user,
        address[] calldata path,
        uint256[] calldata amounts
    ) public view override returns (bool isAttack) {
        // Check if user is trying to front-run a large trade
        if (amounts[0] > minLiquidity * 10) { // 10x minimum liquidity
            return true;
        }
        
        // Check for suspicious timing
        if (block.timestamp - lastTradeTime[user] < 10) { // Within 10 seconds
            return true;
        }
        
        return false;
    }
    
    /**
     * @dev Detect back-running
     * @param user User address
     * @param path Swap path
     * @param amounts Swap amounts
     * @return isAttack Whether it's back-running
     */
    function isBackRunning(
        address user,
        address[] calldata path,
        uint256[] calldata amounts
    ) public view override returns (bool isAttack) {
        // Check if user is trying to back-run a large trade
        if (amounts[amounts.length - 1] > minLiquidity * 10) { // 10x minimum liquidity
            return true;
        }
        
        return false;
    }
    
    /**
     * @dev Detect liquidity manipulation
     * @param user User address
     * @param path Swap path
     * @param amounts Swap amounts
     * @return isAttack Whether it's liquidity manipulation
     */
    function isLiquidityManipulation(
        address user,
        address[] calldata path,
        uint256[] calldata amounts
    ) public view override returns (bool isAttack) {
        // Check if user is trying to manipulate liquidity
        if (amounts[0] > minLiquidity * 5) { // 5x minimum liquidity
            return true;
        }
        
        return false;
    }
    
    /**
     * @dev Detect governance manipulation
     * @param proposer Proposer address
     * @param targets Proposal targets
     * @param values Proposal values
     * @return isAttack Whether it's governance manipulation
     */
    function isGovernanceManipulation(
        address proposer,
        address[] calldata targets,
        uint256[] calldata values
    ) public view override returns (bool isAttack) {
        // Check if proposer is trying to manipulate governance
        if (targets.length > 5) { // Too many targets
            return true;
        }
        
        // Check for suspicious values
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] > 1000 ether) { // Large ETH values
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @dev Detect staking manipulation
     * @param user User address
     * @param target Target contract
     * @param amount Staking amount
     * @return isAttack Whether it's staking manipulation
     */
    function isStakingManipulation(
        address user,
        address target,
        uint256 amount
    ) public view override returns (bool isAttack) {
        // Check if user is trying to manipulate staking
        if (amount > minLiquidity * 10) { // 10x minimum liquidity
            return true;
        }
        
        return false;
    }
    
    /**
     * @dev Calculate price impact
     * @param path Swap path
     * @param amounts Swap amounts
     * @return priceImpact Price impact percentage
     */
    function calculatePriceImpact(
        address[] calldata path,
        uint256[] calldata amounts
    ) public view override returns (uint256 priceImpact) {
        if (amounts.length < 2) {
            return 0;
        }
        
        // Calculate price impact based on amounts
        uint256 inputAmount = amounts[0];
        uint256 outputAmount = amounts[amounts.length - 1];
        
        if (inputAmount == 0 || outputAmount == 0) {
            return 0;
        }
        
        // Simple price impact calculation
        // This would need to be more sophisticated in a real implementation
        priceImpact = (inputAmount * 10000) / outputAmount;
        
        return priceImpact;
    }
    
    /**
     * @dev Report MEV attack
     * @param attacker Attacker address
     * @param attackType Type of attack
     * @param severity Attack severity
     */
    function reportMEVAttack(
        address attacker,
        string calldata attackType,
        uint256 severity
    ) external override onlySecurityManager {
        require(attacker != address(0), "MEVProtection: ZERO_ADDRESS");
        require(severity > 0 && severity <= 10, "MEVProtection: INVALID_SEVERITY");
        
        suspiciousActivity[attacker] += severity;
        
        if (suspiciousActivity[attacker] >= 50) { // Threshold for blacklisting
            isBlacklisted[attacker] = true;
        }
        
        emit MEVAttackDetected(attacker, attackType, severity);
    }
    
    /**
     * @dev Update blacklist status
     * @param account Account to update
     * @param blacklisted Blacklist status
     */
    function updateBlacklist(address account, bool blacklisted) external override onlySecurityManager {
        require(account != address(0), "MEVProtection: ZERO_ADDRESS");
        isBlacklisted[account] = blacklisted;
        emit BlacklistUpdated(account, blacklisted);
    }
    
    /**
     * @dev Set security manager
     * @param _securityManager New security manager address
     */
    function setSecurityManager(address _securityManager) external override onlyOwner {
        require(_securityManager != address(0), "MEVProtection: ZERO_ADDRESS");
        securityManager = _securityManager;
        emit SecurityManagerChanged(_securityManager);
    }
    
    /**
     * @dev Set oracle address
     * @param _oracle New oracle address
     */
    function setOracle(address _oracle) external override onlyOwner {
        require(_oracle != address(0), "MEVProtection: ZERO_ADDRESS");
        oracle = _oracle;
        emit OracleChanged(_oracle);
    }
    
    /**
     * @dev Update MEV protection parameters
     * @param _maxSlippage New maximum slippage
     * @param _maxPriceImpact New maximum price impact
     * @param _minLiquidity New minimum liquidity
     * @param _maxGasPrice New maximum gas price
     */
    function updateParameters(
        uint256 _maxSlippage,
        uint256 _maxPriceImpact,
        uint256 _minLiquidity,
        uint256 _maxGasPrice
    ) external override onlySecurityManager {
        require(_maxSlippage <= 10000, "MEVProtection: INVALID_MAX_SLIPPAGE");
        require(_maxPriceImpact <= 10000, "MEVProtection: INVALID_MAX_PRICE_IMPACT");
        require(_minLiquidity > 0, "MEVProtection: INVALID_MIN_LIQUIDITY");
        require(_maxGasPrice > 0, "MEVProtection: INVALID_MAX_GAS_PRICE");
        
        maxSlippage = _maxSlippage;
        maxPriceImpact = _maxPriceImpact;
        minLiquidity = _minLiquidity;
        maxGasPrice = _maxGasPrice;
        
        emit ParametersUpdated(_maxSlippage, _maxPriceImpact, _minLiquidity, _maxGasPrice);
    }
    
    /**
     * @dev Pause the MEV protection (emergency function)
     */
    function pause() external override onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the MEV protection
     */
    function unpause() external override onlyOwner {
        _unpause();
    }
}

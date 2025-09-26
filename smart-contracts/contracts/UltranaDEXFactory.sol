// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IUltranaDEXFactory.sol";
import "./interfaces/IUltranaDEXPair.sol";
import "./UltranaDEXPair.sol";

/**
 * @title UltranaDEXFactory
 * @dev Factory contract for creating and managing Ultrana DEX pairs
 * @notice This contract handles the creation of trading pairs and manages fees
 */
contract UltranaDEXFactory is IUltranaDEXFactory, Ownable, ReentrancyGuard, Pausable {
    // State variables
    address public override feeTo;
    address public override feeToSetter;
    address public override router;
    address public override securityManager;
    
    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;
    
    // Fee tiers for different pair types
    mapping(uint24 => FeeTier) public override feeTiers;
    uint24 public override defaultFeeTier = 3000; // 0.3%
    
    // Security features
    mapping(address => bool) public override isAuthorizedPair;
    mapping(address => bool) public override isBlacklistedToken;
    
    // Events
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    event FeeToChanged(address indexed feeTo);
    event FeeToSetterChanged(address indexed feeToSetter);
    event RouterChanged(address indexed router);
    event SecurityManagerChanged(address indexed securityManager);
    event FeeTierUpdated(uint24 indexed feeTier, uint24 fee, uint24 tickSpacing);
    event TokenBlacklisted(address indexed token, bool blacklisted);
    event PairAuthorized(address indexed pair, bool authorized);
    
    // Modifiers
    modifier onlyRouter() {
        require(msg.sender == router, "UltranaDEXFactory: FORBIDDEN");
        _;
    }
    
    modifier onlySecurityManager() {
        require(msg.sender == securityManager, "UltranaDEXFactory: FORBIDDEN");
        _;
    }
    
    constructor(address _feeToSetter) {
        require(_feeToSetter != address(0), "UltranaDEXFactory: ZERO_ADDRESS");
        feeToSetter = _feeToSetter;
        
        // Initialize default fee tiers
        feeTiers[100] = FeeTier(100, 1); // 0.01% - 1 tick spacing
        feeTiers[500] = FeeTier(500, 10); // 0.05% - 10 tick spacing
        feeTiers[3000] = FeeTier(3000, 60); // 0.3% - 60 tick spacing
        feeTiers[10000] = FeeTier(10000, 200); // 1% - 200 tick spacing
    }
    
    /**
     * @dev Create a new trading pair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param feeTier Fee tier for the pair
     * @return pair Address of the created pair
     */
    function createPair(
        address tokenA,
        address tokenB,
        uint24 feeTier
    ) external override nonReentrant whenNotPaused returns (address pair) {
        require(tokenA != tokenB, "UltranaDEXFactory: IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "UltranaDEXFactory: ZERO_ADDRESS");
        require(!isBlacklistedToken[tokenA] && !isBlacklistedToken[tokenB], "UltranaDEXFactory: BLACKLISTED_TOKEN");
        require(feeTiers[feeTier].fee != 0, "UltranaDEXFactory: INVALID_FEE_TIER");
        
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UltranaDEXFactory: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "UltranaDEXFactory: PAIR_EXISTS");
        
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, feeTier));
        pair = address(new UltranaDEXPair{salt: salt}());
        
        IUltranaDEXPair(pair).initialize(token0, token1, feeTier);
        
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        
        isAuthorizedPair[pair] = true;
        
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
    
    /**
     * @dev Set the fee recipient address
     * @param _feeTo New fee recipient address
     */
    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "UltranaDEXFactory: FORBIDDEN");
        feeTo = _feeTo;
        emit FeeToChanged(_feeTo);
    }
    
    /**
     * @dev Set the fee setter address
     * @param _feeToSetter New fee setter address
     */
    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "UltranaDEXFactory: FORBIDDEN");
        feeToSetter = _feeToSetter;
        emit FeeToSetterChanged(_feeToSetter);
    }
    
    /**
     * @dev Set the router address
     * @param _router New router address
     */
    function setRouter(address _router) external override onlyOwner {
        require(_router != address(0), "UltranaDEXFactory: ZERO_ADDRESS");
        router = _router;
        emit RouterChanged(_router);
    }
    
    /**
     * @dev Set the security manager address
     * @param _securityManager New security manager address
     */
    function setSecurityManager(address _securityManager) external override onlyOwner {
        require(_securityManager != address(0), "UltranaDEXFactory: ZERO_ADDRESS");
        securityManager = _securityManager;
        emit SecurityManagerChanged(_securityManager);
    }
    
    /**
     * @dev Update fee tier configuration
     * @param feeTier Fee tier to update
     * @param fee Fee amount in basis points
     * @param tickSpacing Tick spacing for the fee tier
     */
    function updateFeeTier(
        uint24 feeTier,
        uint24 fee,
        uint24 tickSpacing
    ) external override onlyOwner {
        require(fee <= 10000, "UltranaDEXFactory: INVALID_FEE"); // Max 100%
        require(tickSpacing > 0, "UltranaDEXFactory: INVALID_TICK_SPACING");
        
        feeTiers[feeTier] = FeeTier(fee, tickSpacing);
        emit FeeTierUpdated(feeTier, fee, tickSpacing);
    }
    
    /**
     * @dev Blacklist or whitelist a token
     * @param token Token address to blacklist/whitelist
     * @param blacklisted Blacklist status
     */
    function setTokenBlacklist(address token, bool blacklisted) external override onlySecurityManager {
        require(token != address(0), "UltranaDEXFactory: ZERO_ADDRESS");
        isBlacklistedToken[token] = blacklisted;
        emit TokenBlacklisted(token, blacklisted);
    }
    
    /**
     * @dev Authorize or deauthorize a pair
     * @param pair Pair address to authorize/deauthorize
     * @param authorized Authorization status
     */
    function setPairAuthorization(address pair, bool authorized) external override onlySecurityManager {
        require(pair != address(0), "UltranaDEXFactory: ZERO_ADDRESS");
        isAuthorizedPair[pair] = authorized;
        emit PairAuthorized(pair, authorized);
    }
    
    /**
     * @dev Pause the factory (emergency function)
     */
    function pause() external override onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the factory
     */
    function unpause() external override onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Get the number of pairs
     * @return Number of pairs
     */
    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }
    
    /**
     * @dev Get pair address for two tokens
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return pair Pair address
     */
    function getPairAddress(address tokenA, address tokenB) external view override returns (address pair) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return getPair[token0][token1];
    }
    
    /**
     * @dev Check if a pair exists
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return exists Whether the pair exists
     */
    function pairExists(address tokenA, address tokenB) external view override returns (bool exists) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return getPair[token0][token1] != address(0);
    }
}

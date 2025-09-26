// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IUltranaDEXRouter.sol";
import "./interfaces/IUltranaDEXFactory.sol";
import "./interfaces/IUltranaDEXPair.sol";
import "./interfaces/IWETH.sol";
import "./libraries/UltranaDEXLibrary.sol";
import "./security/MEVProtection.sol";
import "./security/SlippageProtection.sol";

/**
 * @title UltranaDEXRouter
 * @dev Router contract for executing trades and managing liquidity
 * @notice This contract provides the main interface for DEX operations
 */
contract UltranaDEXRouter is IUltranaDEXRouter, ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;
    
    // State variables
    address public override factory;
    address public override WETH;
    address public override securityManager;
    address public override mevProtection;
    address public override slippageProtection;
    
    // Security features
    mapping(address => bool) public override isAuthorized;
    mapping(address => uint256) public override lastTradeTime;
    mapping(address => uint256) public override tradeCooldown;
    uint256 public override maxTradeAmount;
    uint256 public override maxSlippage;
    
    // Events
    event SwapExecuted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event LiquidityAdded(
        address indexed user,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    event LiquidityRemoved(
        address indexed user,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    event SecurityManagerChanged(address indexed securityManager);
    event MEVProtectionChanged(address indexed mevProtection);
    event SlippageProtectionChanged(address indexed slippageProtection);
    event AuthorizationChanged(address indexed account, bool authorized);
    event MaxTradeAmountChanged(uint256 maxTradeAmount);
    event MaxSlippageChanged(uint256 maxSlippage);
    event TradeCooldownChanged(address indexed account, uint256 cooldown);
    
    // Modifiers
    modifier onlyAuthorized() {
        require(isAuthorized[msg.sender] || msg.sender == owner(), "UltranaDEXRouter: FORBIDDEN");
        _;
    }
    
    modifier onlySecurityManager() {
        require(msg.sender == securityManager, "UltranaDEXRouter: FORBIDDEN");
        _;
    }
    
    modifier tradeCooldownCheck() {
        require(block.timestamp >= lastTradeTime[msg.sender] + tradeCooldown[msg.sender], "UltranaDEXRouter: TRADE_COOLDOWN");
        _;
    }
    
    constructor(address _factory, address _WETH) {
        require(_factory != address(0), "UltranaDEXRouter: ZERO_ADDRESS");
        require(_WETH != address(0), "UltranaDEXRouter: ZERO_ADDRESS");
        
        factory = _factory;
        WETH = _WETH;
        maxTradeAmount = type(uint256).max;
        maxSlippage = 500; // 5% default max slippage
    }
    
    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }
    
    /**
     * @dev Swap tokens for tokens
     * @param amountIn Amount of input tokens
     * @param amountOutMin Minimum amount of output tokens
     * @param path Array of token addresses representing the swap path
     * @param to Address to receive the output tokens
     * @param deadline Deadline for the transaction
     * @return amounts Array of amounts for each step in the path
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override nonReentrant whenNotPaused onlyAuthorized tradeCooldownCheck returns (uint256[] memory amounts) {
        require(amountIn <= maxTradeAmount, "UltranaDEXRouter: EXCEEDS_MAX_TRADE");
        require(deadline >= block.timestamp, "UltranaDEXRouter: EXPIRED");
        require(path.length >= 2, "UltranaDEXRouter: INVALID_PATH");
        
        amounts = UltranaDEXLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "UltranaDEXRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        
        // Check slippage protection
        if (slippageProtection != address(0)) {
            require(ISlippageProtection(slippageProtection).checkSlippage(path, amounts, maxSlippage), "UltranaDEXRouter: SLIPPAGE_EXCEEDED");
        }
        
        // Check MEV protection
        if (mevProtection != address(0)) {
            require(IMEVProtection(mevProtection).checkMEVProtection(msg.sender, path, amounts), "UltranaDEXRouter: MEV_PROTECTION_FAILED");
        }
        
        IERC20(path[0]).safeTransferFrom(msg.sender, UltranaDEXLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
        
        lastTradeTime[msg.sender] = block.timestamp;
        emit SwapExecuted(msg.sender, path[0], path[path.length - 1], amountIn, amounts[amounts.length - 1], 0);
    }
    
    /**
     * @dev Swap tokens for ETH
     * @param amountIn Amount of input tokens
     * @param amountOutMin Minimum amount of ETH to receive
     * @param path Array of token addresses representing the swap path
     * @param to Address to receive the ETH
     * @param deadline Deadline for the transaction
     * @return amounts Array of amounts for each step in the path
     */
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override nonReentrant whenNotPaused onlyAuthorized tradeCooldownCheck returns (uint256[] memory amounts) {
        require(amountIn <= maxTradeAmount, "UltranaDEXRouter: EXCEEDS_MAX_TRADE");
        require(deadline >= block.timestamp, "UltranaDEXRouter: EXPIRED");
        require(path[path.length - 1] == WETH, "UltranaDEXRouter: INVALID_PATH");
        
        amounts = UltranaDEXLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "UltranaDEXRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        
        // Check slippage protection
        if (slippageProtection != address(0)) {
            require(ISlippageProtection(slippageProtection).checkSlippage(path, amounts, maxSlippage), "UltranaDEXRouter: SLIPPAGE_EXCEEDED");
        }
        
        // Check MEV protection
        if (mevProtection != address(0)) {
            require(IMEVProtection(mevProtection).checkMEVProtection(msg.sender, path, amounts), "UltranaDEXRouter: MEV_PROTECTION_FAILED");
        }
        
        IERC20(path[0]).safeTransferFrom(msg.sender, UltranaDEXLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        
        lastTradeTime[msg.sender] = block.timestamp;
        emit SwapExecuted(msg.sender, path[0], WETH, amountIn, amounts[amounts.length - 1], 0);
    }
    
    /**
     * @dev Swap ETH for tokens
     * @param amountOutMin Minimum amount of tokens to receive
     * @param path Array of token addresses representing the swap path
     * @param to Address to receive the tokens
     * @param deadline Deadline for the transaction
     * @return amounts Array of amounts for each step in the path
     */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override payable nonReentrant whenNotPaused onlyAuthorized tradeCooldownCheck returns (uint256[] memory amounts) {
        require(msg.value <= maxTradeAmount, "UltranaDEXRouter: EXCEEDS_MAX_TRADE");
        require(deadline >= block.timestamp, "UltranaDEXRouter: EXPIRED");
        require(path[0] == WETH, "UltranaDEXRouter: INVALID_PATH");
        
        amounts = UltranaDEXLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "UltranaDEXRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        
        // Check slippage protection
        if (slippageProtection != address(0)) {
            require(ISlippageProtection(slippageProtection).checkSlippage(path, amounts, maxSlippage), "UltranaDEXRouter: SLIPPAGE_EXCEEDED");
        }
        
        // Check MEV protection
        if (mevProtection != address(0)) {
            require(IMEVProtection(mevProtection).checkMEVProtection(msg.sender, path, amounts), "UltranaDEXRouter: MEV_PROTECTION_FAILED");
        }
        
        IWETH(WETH).deposit{value: msg.value}();
        assert(IWETH(WETH).transfer(UltranaDEXLibrary.pairFor(factory, path[0], path[1]), msg.value));
        _swap(amounts, path, to);
        
        lastTradeTime[msg.sender] = block.timestamp;
        emit SwapExecuted(msg.sender, WETH, path[path.length - 1], msg.value, amounts[amounts.length - 1], 0);
    }
    
    /**
     * @dev Add liquidity to a pair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param amountADesired Desired amount of tokenA
     * @param amountBDesired Desired amount of tokenB
     * @param amountAMin Minimum amount of tokenA
     * @param amountBMin Minimum amount of tokenB
     * @param to Address to receive the liquidity tokens
     * @param deadline Deadline for the transaction
     * @return amountA Actual amount of tokenA added
     * @return amountB Actual amount of tokenB added
     * @return liquidity Amount of liquidity tokens minted
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external override nonReentrant whenNotPaused onlyAuthorized returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(deadline >= block.timestamp, "UltranaDEXRouter: EXPIRED");
        require(amountADesired <= maxTradeAmount && amountBDesired <= maxTradeAmount, "UltranaDEXRouter: EXCEEDS_MAX_TRADE");
        
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = UltranaDEXLibrary.pairFor(factory, tokenA, tokenB);
        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);
        liquidity = IUltranaDEXPair(pair).mint(to);
        
        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB, liquidity);
    }
    
    /**
     * @dev Remove liquidity from a pair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @param liquidity Amount of liquidity tokens to burn
     * @param amountAMin Minimum amount of tokenA to receive
     * @param amountBMin Minimum amount of tokenB to receive
     * @param to Address to receive the underlying tokens
     * @param deadline Deadline for the transaction
     * @return amountA Actual amount of tokenA received
     * @return amountB Actual amount of tokenB received
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external override nonReentrant whenNotPaused onlyAuthorized returns (uint256 amountA, uint256 amountB) {
        require(deadline >= block.timestamp, "UltranaDEXRouter: EXPIRED");
        
        address pair = UltranaDEXLibrary.pairFor(factory, tokenA, tokenB);
        IUltranaDEXPair(pair).transferFrom(msg.sender, pair, liquidity);
        (amountA, amountB) = IUltranaDEXPair(pair).burn(to);
        require(amountA >= amountAMin, "UltranaDEXRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "UltranaDEXRouter: INSUFFICIENT_B_AMOUNT");
        
        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB, liquidity);
    }
    
    /**
     * @dev Get amounts out for a given input amount
     * @param amountIn Input amount
     * @param path Swap path
     * @return amounts Array of amounts for each step
     */
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view override returns (uint256[] memory amounts) {
        return UltranaDEXLibrary.getAmountsOut(factory, amountIn, path);
    }
    
    /**
     * @dev Get amounts in for a given output amount
     * @param amountOut Output amount
     * @param path Swap path
     * @return amounts Array of amounts for each step
     */
    function getAmountsIn(uint256 amountOut, address[] calldata path) external view override returns (uint256[] memory amounts) {
        return UltranaDEXLibrary.getAmountsIn(factory, amountOut, path);
    }
    
    /**
     * @dev Set security manager
     * @param _securityManager New security manager address
     */
    function setSecurityManager(address _securityManager) external override onlyOwner {
        require(_securityManager != address(0), "UltranaDEXRouter: ZERO_ADDRESS");
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
     * @dev Set slippage protection contract
     * @param _slippageProtection New slippage protection address
     */
    function setSlippageProtection(address _slippageProtection) external override onlyOwner {
        slippageProtection = _slippageProtection;
        emit SlippageProtectionChanged(_slippageProtection);
    }
    
    /**
     * @dev Set authorization for an address
     * @param account Address to authorize/deauthorize
     * @param authorized Authorization status
     */
    function setAuthorization(address account, bool authorized) external override onlySecurityManager {
        require(account != address(0), "UltranaDEXRouter: ZERO_ADDRESS");
        isAuthorized[account] = authorized;
        emit AuthorizationChanged(account, authorized);
    }
    
    /**
     * @dev Set maximum trade amount
     * @param _maxTradeAmount Maximum trade amount
     */
    function setMaxTradeAmount(uint256 _maxTradeAmount) external override onlySecurityManager {
        maxTradeAmount = _maxTradeAmount;
        emit MaxTradeAmountChanged(_maxTradeAmount);
    }
    
    /**
     * @dev Set maximum slippage
     * @param _maxSlippage Maximum slippage in basis points
     */
    function setMaxSlippage(uint256 _maxSlippage) external override onlySecurityManager {
        require(_maxSlippage <= 10000, "UltranaDEXRouter: INVALID_SLIPPAGE");
        maxSlippage = _maxSlippage;
        emit MaxSlippageChanged(_maxSlippage);
    }
    
    /**
     * @dev Set trade cooldown for an address
     * @param account Address to set cooldown for
     * @param cooldown Cooldown period in seconds
     */
    function setTradeCooldown(address account, uint256 cooldown) external override onlySecurityManager {
        require(account != address(0), "UltranaDEXRouter: ZERO_ADDRESS");
        tradeCooldown[account] = cooldown;
        emit TradeCooldownChanged(account, cooldown);
    }
    
    /**
     * @dev Pause the router (emergency function)
     */
    function pause() external override onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the router
     */
    function unpause() external override onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Internal function to add liquidity
     */
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        if (IUltranaDEXFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUltranaDEXFactory(factory).createPair(tokenA, tokenB, 3000); // Default 0.3% fee
        }
        (uint256 reserveA, uint256 reserveB) = UltranaDEXLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = UltranaDEXLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "UltranaDEXRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = UltranaDEXLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "UltranaDEXRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    
    /**
     * @dev Internal function to execute swaps
     */
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UltranaDEXLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? UltranaDEXLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IUltranaDEXPair(UltranaDEXLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
}

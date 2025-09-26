// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IUltranaDEXPair.sol";
import "./interfaces/IUltranaDEXFactory.sol";
import "./interfaces/IUltranaDEXRouter.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";

/**
 * @title UltranaDEXPair
 * @dev Core trading pair contract with AMM functionality
 * @notice This contract handles token swaps, liquidity provision, and fee collection
 */
contract UltranaDEXPair is IUltranaDEXPair, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using UQ112x112 for uint224;

    // Constants
    uint256 public constant override MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
    
    // State variables
    address public override factory;
    address public override token0;
    address public override token1;
    uint24 public override feeTier;
    
    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves
    
    uint256 public override price0CumulativeLast;
    uint256 public override price1CumulativeLast;
    uint256 public override kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event
    
    // Security features
    mapping(address => bool) public override isAuthorized;
    mapping(address => uint256) public override lastSwapTime;
    uint256 public override maxSwapAmount;
    uint256 public override swapCooldown;
    
    // Events
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    event AuthorizationChanged(address indexed account, bool authorized);
    event MaxSwapAmountChanged(uint256 maxSwapAmount);
    event SwapCooldownChanged(uint256 swapCooldown);
    
    // Modifiers
    modifier onlyFactory() {
        require(msg.sender == factory, "UltranaDEXPair: FORBIDDEN");
        _;
    }
    
    modifier onlyAuthorized() {
        require(isAuthorized[msg.sender] || msg.sender == factory, "UltranaDEXPair: FORBIDDEN");
        _;
    }
    
    modifier swapCooldownCheck() {
        require(block.timestamp >= lastSwapTime[msg.sender] + swapCooldown, "UltranaDEXPair: SWAP_COOLDOWN");
        _;
    }
    
    constructor() {
        factory = msg.sender;
    }
    
    /**
     * @dev Initialize the pair
     * @param _token0 First token address
     * @param _token1 Second token address
     * @param _feeTier Fee tier for the pair
     */
    function initialize(address _token0, address _token1, uint24 _feeTier) external override {
        require(msg.sender == factory, "UltranaDEXPair: FORBIDDEN");
        require(_token0 != _token1, "UltranaDEXPair: IDENTICAL_ADDRESSES");
        require(_token0 != address(0) && _token1 != address(0), "UltranaDEXPair: ZERO_ADDRESS");
        
        token0 = _token0;
        token1 = _token1;
        feeTier = _feeTier;
        
        // Initialize security parameters
        maxSwapAmount = type(uint256).max;
        swapCooldown = 0;
    }
    
    /**
     * @dev Get the current reserves
     * @return _reserve0 Reserve of token0
     * @return _reserve1 Reserve of token1
     * @return _blockTimestampLast Last block timestamp
     */
    function getReserves() public view override returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }
    
    /**
     * @dev Get the current price
     * @return price0 Price of token0 in terms of token1
     * @return price1 Price of token1 in terms of token0
     */
    function getPrice() external view override returns (uint256 price0, uint256 price1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(_reserve0 > 0 && _reserve1 > 0, "UltranaDEXPair: INSUFFICIENT_LIQUIDITY");
        price0 = (uint256(_reserve1) * 1e18) / uint256(_reserve0);
        price1 = (uint256(_reserve0) * 1e18) / uint256(_reserve1);
    }
    
    /**
     * @dev Mint liquidity tokens
     * @param to Address to receive the liquidity tokens
     * @return liquidity Amount of liquidity tokens minted
     */
    function mint(address to) external override nonReentrant whenNotPaused onlyAuthorized returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;
        
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply();
        
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
        }
        
        require(liquidity > 0, "UltranaDEXPair: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);
        
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        
        emit Mint(msg.sender, amount0, amount1);
    }
    
    /**
     * @dev Burn liquidity tokens
     * @param to Address to receive the underlying tokens
     * @return amount0 Amount of token0 returned
     * @return amount1 Amount of token1 returned
     */
    function burn(address to) external override nonReentrant whenNotPaused onlyAuthorized returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];
        
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply();
        amount0 = liquidity * balance0 / _totalSupply;
        amount1 = liquidity * balance1 / _totalSupply;
        
        require(amount0 > 0 && amount1 > 0, "UltranaDEXPair: INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        
        IERC20(_token0).safeTransfer(to, amount0);
        IERC20(_token1).safeTransfer(to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1;
        
        emit Burn(msg.sender, amount0, amount1, to);
    }
    
    /**
     * @dev Swap tokens
     * @param amount0Out Amount of token0 to output
     * @param amount1Out Amount of token1 to output
     * @param to Address to receive the output tokens
     * @param data Additional data for the swap
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external override nonReentrant whenNotPaused onlyAuthorized swapCooldownCheck {
        require(amount0Out > 0 || amount1Out > 0, "UltranaDEXPair: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "UltranaDEXPair: INSUFFICIENT_LIQUIDITY");
        
        uint256 balance0;
        uint256 balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "UltranaDEXPair: INVALID_TO");
            if (amount0Out > 0) IERC20(_token0).safeTransfer(to, amount0Out);
            if (amount1Out > 0) IERC20(_token1).safeTransfer(to, amount1Out);
            if (data.length > 0) IUltranaDEXCallee(to).ultranaDEXCall(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "UltranaDEXPair: INSUFFICIENT_INPUT_AMOUNT");
        
        {
            uint256 balance0Adjusted = balance0 * 10000 - amount0In * getFee();
            uint256 balance1Adjusted = balance1 * 10000 - amount1In * getFee();
            require(balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * 10000**2, "UltranaDEXPair: K");
        }
        
        _update(balance0, balance1, _reserve0, _reserve1);
        lastSwapTime[msg.sender] = block.timestamp;
        
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }
    
    /**
     * @dev Sync reserves
     */
    function sync() external override nonReentrant whenNotPaused onlyAuthorized {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
    
    /**
     * @dev Get the fee for this pair
     * @return fee Fee in basis points
     */
    function getFee() public view override returns (uint256 fee) {
        IUltranaDEXFactory _factory = IUltranaDEXFactory(factory);
        IUltranaDEXFactory.FeeTier memory feeTierInfo = _factory.feeTiers(feeTier);
        return feeTierInfo.fee;
    }
    
    /**
     * @dev Set authorization for an address
     * @param account Address to authorize/deauthorize
     * @param authorized Authorization status
     */
    function setAuthorization(address account, bool authorized) external override onlyFactory {
        require(account != address(0), "UltranaDEXPair: ZERO_ADDRESS");
        isAuthorized[account] = authorized;
        emit AuthorizationChanged(account, authorized);
    }
    
    /**
     * @dev Set maximum swap amount
     * @param _maxSwapAmount Maximum swap amount
     */
    function setMaxSwapAmount(uint256 _maxSwapAmount) external override onlyFactory {
        maxSwapAmount = _maxSwapAmount;
        emit MaxSwapAmountChanged(_maxSwapAmount);
    }
    
    /**
     * @dev Set swap cooldown
     * @param _swapCooldown Swap cooldown in seconds
     */
    function setSwapCooldown(uint256 _swapCooldown) external override onlyFactory {
        swapCooldown = _swapCooldown;
        emit SwapCooldownChanged(_swapCooldown);
    }
    
    /**
     * @dev Pause the pair (emergency function)
     */
    function pause() external override onlyFactory {
        _pause();
    }
    
    /**
     * @dev Unpause the pair
     */
    function unpause() external override onlyFactory {
        _unpause();
    }
    
    /**
     * @dev Internal function to update reserves
     */
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "UltranaDEXPair: OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        
        emit Sync(reserve0, reserve1);
    }
    
    /**
     * @dev Internal function to mint fees
     */
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUltranaDEXFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;
        
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }
}

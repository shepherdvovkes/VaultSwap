// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IUltranaDEXPair {
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
    
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function feeTier() external view returns (uint24);
    
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function getPrice() external view returns (uint256 price0, uint256 price1);
    function getFee() external view returns (uint256 fee);
    
    function initialize(address _token0, address _token1, uint24 _feeTier) external;
    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function sync() external;
    
    function setAuthorization(address account, bool authorized) external;
    function setMaxSwapAmount(uint256 _maxSwapAmount) external;
    function setSwapCooldown(uint256 _swapCooldown) external;
    function pause() external;
    function unpause() external;
    
    function isAuthorized(address) external view returns (bool);
    function lastSwapTime(address) external view returns (uint256);
    function maxSwapAmount() external view returns (uint256);
    function swapCooldown() external view returns (uint256);
    
    function MINIMUM_LIQUIDITY() external pure returns (uint256);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function kLast() external view returns (uint256);
}

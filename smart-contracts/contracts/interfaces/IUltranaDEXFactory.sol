// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IUltranaDEXFactory {
    struct FeeTier {
        uint24 fee;
        uint24 tickSpacing;
    }
    
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    event FeeToChanged(address indexed feeTo);
    event FeeToSetterChanged(address indexed feeToSetter);
    event RouterChanged(address indexed router);
    event SecurityManagerChanged(address indexed securityManager);
    event FeeTierUpdated(uint24 indexed feeTier, uint24 fee, uint24 tickSpacing);
    event TokenBlacklisted(address indexed token, bool blacklisted);
    event PairAuthorized(address indexed pair, bool authorized);
    
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function router() external view returns (address);
    function securityManager() external view returns (address);
    
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);
    
    function createPair(address tokenA, address tokenB, uint24 feeTier) external returns (address pair);
    function getPairAddress(address tokenA, address tokenB) external view returns (address pair);
    function pairExists(address tokenA, address tokenB) external view returns (bool exists);
    
    function setFeeTo(address _feeTo) external;
    function setFeeToSetter(address _feeToSetter) external;
    function setRouter(address _router) external;
    function setSecurityManager(address _securityManager) external;
    function updateFeeTier(uint24 feeTier, uint24 fee, uint24 tickSpacing) external;
    function setTokenBlacklist(address token, bool blacklisted) external;
    function setPairAuthorization(address pair, bool authorized) external;
    
    function pause() external;
    function unpause() external;
    
    function feeTiers(uint24) external view returns (FeeTier memory);
    function defaultFeeTier() external view returns (uint24);
    function isAuthorizedPair(address) external view returns (bool);
    function isBlacklistedToken(address) external view returns (bool);
}

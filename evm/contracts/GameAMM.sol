// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// GameAMM: Constant product AMM (x*y=k) for token-to-token swaps on Flow EVM.
// Simplified UniswapV2-style pair. 0.3% swap fee (configurable).
// LP tokens represent proportional share of the pool.

contract GameAMM is ERC20, ReentrancyGuard {
    IERC20 public immutable token0;  // e.g., GameToken20
    IERC20 public immutable token1;  // e.g., WFLOW (wrapped FLOW)

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public constant FEE_BPS = 30;  // 0.30%
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    address public feeTo;  // fee recipient (StakingPool or treasury)

    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, bool zeroForOne);
    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 lpTokens);
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 lpTokens);

    constructor(address _token0, address _token1, address _feeTo)
        ERC20("GameAMM-LP", "GLP")
    {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        feeTo = _feeTo;
    }

    // Add liquidity — receive LP tokens proportional to contribution
    function addLiquidity(uint256 amount0, uint256 amount1, address to)
        external nonReentrant returns (uint256 lpTokens)
    {
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        uint256 supply = totalSupply();
        if (supply == 0) {
            lpTokens = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0xdead), MINIMUM_LIQUIDITY);  // permanently locked
        } else {
            lpTokens = min(
                amount0 * supply / reserve0,
                amount1 * supply / reserve1
            );
        }
        require(lpTokens > 0, "Insufficient liquidity minted");
        _mint(to, lpTokens);

        reserve0 += amount0;
        reserve1 += amount1;
        emit LiquidityAdded(to, amount0, amount1, lpTokens);
    }

    // Remove liquidity — burn LP tokens, receive token0 + token1
    function removeLiquidity(uint256 lpTokens, address to)
        external nonReentrant returns (uint256 amount0, uint256 amount1)
    {
        uint256 supply = totalSupply();
        amount0 = lpTokens * reserve0 / supply;
        amount1 = lpTokens * reserve1 / supply;
        require(amount0 > 0 && amount1 > 0, "Insufficient liquidity burned");

        _burn(msg.sender, lpTokens);
        token0.transfer(to, amount0);
        token1.transfer(to, amount1);
        reserve0 -= amount0;
        reserve1 -= amount1;
        emit LiquidityRemoved(to, amount0, amount1, lpTokens);
    }

    // Swap token0 for token1 (or reverse)
    function swap(uint256 amountIn, bool zeroForOne, uint256 minAmountOut, address to)
        external nonReentrant returns (uint256 amountOut)
    {
        require(amountIn > 0, "Zero input");

        uint256 amountInWithFee = amountIn * (10000 - FEE_BPS) / 10000;

        if (zeroForOne) {
            // token0 -> token1: k = reserve0 * reserve1
            amountOut = reserve1 - (reserve0 * reserve1) / (reserve0 + amountInWithFee);
            require(amountOut >= minAmountOut, "Slippage exceeded");
            token0.transferFrom(msg.sender, address(this), amountIn);
            token1.transfer(to, amountOut);
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            amountOut = reserve0 - (reserve0 * reserve1) / (reserve1 + amountInWithFee);
            require(amountOut >= minAmountOut, "Slippage exceeded");
            token1.transferFrom(msg.sender, address(this), amountIn);
            token0.transfer(to, amountOut);
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }

        emit Swap(msg.sender, amountIn, amountOut, zeroForOne);
    }

    // Price quote (no state change)
    function getAmountOut(uint256 amountIn, bool zeroForOne) external view returns (uint256) {
        uint256 amountInWithFee = amountIn * (10000 - FEE_BPS) / 10000;
        uint256 rIn = zeroForOne ? reserve0 : reserve1;
        uint256 rOut = zeroForOne ? reserve1 : reserve0;
        return rOut - (rIn * rOut) / (rIn + amountInWithFee);
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) { z = y; uint256 x = y / 2 + 1; while (x < z) { z = x; x = (y / x + x) / 2; } }
        else if (y != 0) z = 1;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) { return a < b ? a : b; }
}

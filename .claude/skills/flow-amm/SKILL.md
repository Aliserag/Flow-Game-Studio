# /flow-amm

Design and deploy automated market maker contracts for Flow game economies.

## Usage

- `/flow-amm bonding-curve --base-price 0.001 --slope 0.0001 --sell-spread 5` — deploy Cadence bonding curve
- `/flow-amm evm-pair --token0 GameToken20 --token1 WFLOW` — deploy EVM constant product AMM
- `/flow-amm quote --amm evm --amount-in 100 --zero-for-one` — get swap price quote
- `/flow-amm analyze` — audit AMM parameters for economic soundness

## Which AMM for Which Use Case

| Use Case | Contract | Why |
|----------|----------|-----|
| Token primary issuance / initial price discovery | `BondingCurve.cdc` (Cadence) | Automatic price increase as adoption grows; treasury accumulates FLOW reserve |
| Secondary market token swaps for EVM users | `GameAMM.sol` (EVM) | DEX-compatible, LP token rewards, deep liquidity |
| In-game item pricing (admin-controlled) | `DynamicPricing.cdc` | Fixed prices with discount windows |

## Bonding Curve Parameters

| Parameter | Conservative | Aggressive |
|-----------|-------------|------------|
| basePrice | 0.001 FLOW | 0.0001 FLOW |
| slope | 0.000001 | 0.00001 |
| sellSpread | 5% | 2% |

Higher slope = faster price appreciation = more volatile = higher whale risk.
Run `/flow-economics-audit` after setting parameters.

## AMM Invariant

Constant product AMM: `x * y = k`
- Price of token0 in token1 = `reserve1 / reserve0`
- After swap: new reserves must satisfy `(reserve0 + amountIn_with_fee) * (reserve1 - amountOut) = k`
- 0.30% fee stays in the pool, accruing to LP holders

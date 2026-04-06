# Cadence 1.0 Coding Standards

## Naming

- **Contracts**: `PascalCase` (e.g., `GameNFT`, `RandomVRF`)
- **Resources**: `PascalCase` (e.g., `Collection`, `Minter`)
- **Structs**: `PascalCase` (e.g., `GameState`, `Commit`)
- **Entitlements**: `PascalCase` (e.g., `Minter`, `Admin`, `Revealer`)
- **Events**: `PascalCase` (e.g., `Minted`, `Committed`)
- **Functions**: `camelCase` (e.g., `mintNFT`, `processEpoch`)
- **Variables**: `camelCase` (e.g., `totalSupply`, `commitHash`)
- **Constants**: `camelCase` (Flow convention)
- **Files**: `PascalCase.cdc` matching contract name

## Access Control Rules

- Default to `access(self)` — only widen access when needed
- All public contract members: `access(all)`
- Use entitlements for any mutation or privileged operation
- Never expose mutable state directly — use functions with entitlements
- Admin resources: stored at deployer account, never published

## Contract Structure Order

1. Entitlements
2. Events
3. State (constants then variables)
4. Types (structs, enums)
5. Resources (NFT, Collection, Admin/Minter, etc.)
6. Public contract functions
7. `init()`

## Resource Safety

- Every `@Resource` creation must have a corresponding `destroy` path
- Never use `!` (force-unwrap) on optional capabilities — use `?? panic(...)`
- Capabilities must be issued from storage and published explicitly

## Testing Requirements

- Every contract in `cadence/contracts/` must have a corresponding `cadence/tests/` file
- Minimum: deployment test, happy-path test, error/edge-case test
- Run `flow test` before every commit touching `.cdc` files

## Forbidden Patterns

- `pub` / `priv` access modifiers (Cadence 0.x — invalid in 1.0)
- `auth &T` without entitlements (Cadence 0.x)
- Hardcoded account addresses in contracts (use `flow.json` aliases)
- Storing private keys anywhere in the repo
- `force-try` (`try!`) in transactions without clear justification

## Comments

- Every contract: doc comment explaining purpose and pattern used
- Every entitlement: one-line comment explaining who holds it
- Every event: comment on when it fires
- Complex algorithms (VRF derivation, epoch math): step-by-step comments

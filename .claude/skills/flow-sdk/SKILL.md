# /flow-sdk

Generate or update the `@studio/flow-game-sdk` TypeScript module when contracts change.

## Usage

- `/flow-sdk update-addresses` — sync contract addresses after a deploy
- `/flow-sdk add-module <ContractName>` — scaffold a new SDK module for a contract
- `/flow-sdk generate-types` — regenerate TypeScript types from Cadence interfaces

## Address Update Workflow

After every deploy:
1. Read the deploy output (contract address from `flow project deploy`)
2. Update `sdk/src/network-config.ts` with new addresses
3. Rebuild: `cd sdk && npm run build`
4. Bump patch version in `sdk/package.json`
5. Commit: `git commit -m "chore: update SDK contract addresses after deploy"`

## Module Pattern

Every SDK module follows this pattern:

```typescript
export class ContractClient {
  constructor(private network: FlowNetwork) {}

  async readSomething(arg: T): Promise<R> {
    return fcl.query({ cadence: `...`, args: (arg, t) => [...] });
  }

  async writeSomething(arg: T): Promise<string> {
    return fcl.mutate({ cadence: `...`, args: (arg, t) => [...], limit: 100 });
  }
}
```

Scripts (read-only) use `fcl.query()`. Transactions (state-changing) use `fcl.mutate()`.

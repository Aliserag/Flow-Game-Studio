# /flow-governance

Generate governance proposals, voting transactions, and proposal execution for the Governance contract.

## Usage

- `/flow-governance propose --title "Increase minting fee" --action update_price --payload '{"item":"mint","price":200}'`
- `/flow-governance vote --proposal-id 3 --support yes`
- `/flow-governance finalize --proposal-id 3`
- `/flow-governance status --proposal-id 3`

## Governance Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| votingPeriodBlocks | 108,000 | ~3 days |
| quorumPct | 4% | Min % of total supply that must vote |
| passMajorityPct | 51% | Min % of votes that must be YES |
| proposalThreshold | 1,000 tokens | Min holdings to create proposal |

## Key Design Notes

- Voting weight = token balance at `snapshotBlock` (prevent last-minute whale buys)
- One vote per address per proposal
- Execution is permissioned — Admin resource required to prevent replay attacks
- Emergency pause does NOT block voting (governance should work even when game is paused)

## Transaction Templates

Generate full Cadence transaction code for the requested governance action.
Always include the `prepare` block capturing signer address, never use `self.account` in `execute`.

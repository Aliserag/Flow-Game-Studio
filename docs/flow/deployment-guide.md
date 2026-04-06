# Flow Deployment Guide

## Contract Addresses

### Emulator (local development)
Deploy with: `flow project deploy --network emulator`
All contracts deploy to: `0xf8d6e0586b0a20c7` (emulator service account)

### Testnet
Update `.env` with your testnet address and run:
`flow project deploy --network testnet`
Record deployed addresses here after first deployment.

| Contract | Testnet Address | Block |
|----------|----------------|-------|
| GameNFT | TBD | TBD |
| RandomVRF | TBD | TBD |
| Scheduler | TBD | TBD |
| Marketplace | TBD | TBD |

### Mainnet
Requires security audit + multisig approval. See `/flow-testnet` skill.

## Standard Contract Addresses

### Testnet
| Contract | Address |
|----------|---------|
| NonFungibleToken | `0x631e88ae7f1d7c20` |
| MetadataViews | `0x631e88ae7f1d7c20` |
| FungibleToken | `0x9a0766d93b6608b7` |
| RandomBeaconHistory | `0x8c5303eaa26202d6` |

### Mainnet
| Contract | Address |
|----------|---------|
| NonFungibleToken | `0x1d7e57aa55817448` |
| MetadataViews | `0x1d7e57aa55817448` |
| FungibleToken | `0xf233dcee88fe0abe` |
| RandomBeaconHistory | `0xd7431fd358660d73` |

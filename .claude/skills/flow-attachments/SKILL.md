# /flow-attachments

Generate Cadence attachment code for NFT composability.

## Usage

- `/flow-attachments equipment <ContractName>` — generate equipment slot attachment for a specific NFT type
- `/flow-attachments buff <BuffType> <DurationBlocks>` — generate a time-limited buff application
- `/flow-attachments achievement <AchievementId>` — generate achievement grant transaction
- `/flow-attachments read <nftId>` — generate script to read all attachments on an NFT

## Key Cadence 1.0 Attachment Rules

1. **Declaration**: `access(all) attachment Foo for BaseType { ... }`
2. **Attach**: `let result <- attach Foo() to <-resource` — returns the resource with attachment
3. **Access**: `resourceRef[Foo]` — returns `&Foo?` (nil if not attached)
4. **Remove**: `let a <- remove Foo from resource` — removes and returns the attachment
5. **`base` property**: Inside an attachment, `self.base` gives a reference to the host resource
6. **Entitlements propagate**: If caller has `auth(E) &NFT`, they get `auth(E) &Attachment` too

## Why Attachments Beat ERC-6551

ERC-6551 creates a new EVM account for each NFT to hold sub-assets.
Cadence attachments:
- Are first-class resources — typed, movable, destroyable
- Travel with the NFT automatically on transfer
- Can hold their own entitlements separate from the NFT's
- Zero extra accounts needed
- Work with any NFT contract without modification

## When to Use Each Attachment Type

| Attachment | Use for |
|------------|---------|
| `Equipment` | Persistent equipped items (weapon, armor) |
| `Buffs` | Time-limited stat boosts, potions, season bonuses |
| `Achievements` | Permanent provenance, tournament wins, rare drops |

For custom attachments: always extend `NonFungibleToken.NFT` (not a specific contract)
unless you specifically need access to contract-specific fields via `base`.

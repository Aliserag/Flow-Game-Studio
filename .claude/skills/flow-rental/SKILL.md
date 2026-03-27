# /flow-rental

Generate NFT rental and capability lending patterns for Flow games.

## Usage

- `/flow-rental create --nft-id 42 --borrower 0xabc --duration-blocks 6000 --price 5.0`
- `/flow-rental accept --lender 0xdef --rental-id 3`
- `/flow-rental revoke --rental-id 3`
- `/flow-rental status --borrower 0xabc`

## Core Concept: Capabilities, Not Transfers

Flow's capability system enables lending WITHOUT moving the asset:

1. **Lender**: NFT stays in their storage. They issue a limited capability.
2. **Borrower**: Gets a reference via the capability. Can use the NFT in-game logic.
3. **Expiry**: Lender revokes the capability controller — borrower's reference becomes nil.
4. **No recovery needed**: Asset never left lender storage.

## Entitlement Design for Lending

Define what the borrower CAN and CANNOT do:

```cadence
// Borrower CAN:
auth(GameNFT.Use) &GameNFT.NFT       // use in combat, earn XP
auth(GameNFT.Equip) &GameNFT.NFT     // equip to their character

// Borrower CANNOT (no entitlement issued):
// NonFungibleToken.Withdraw          // transfer or sell
// GameNFT.Minter                     // mint new NFTs
```

## Rental vs Direct Borrow

| Pattern | Use when |
|---------|----------|
| NFTLending.cdc (registry + capability) | Peer-to-peer lending with collateral and rental fees |
| Direct capability publish | Trusted game contracts borrowing player assets for a dungeon run |
| Entitlement-scoped borrow in transaction | One-shot in-game use within a single transaction |

## Expiry Enforcement

After `expiresAtBlock`, the lender (or a relayer) calls `revoke_expired_rentals.cdc`.
This calls `capabilityController.delete()` — any reference the borrower holds
immediately returns nil on next borrow attempt.

The borrower CANNOT block revocation — capability revocation is always in the lender's control.

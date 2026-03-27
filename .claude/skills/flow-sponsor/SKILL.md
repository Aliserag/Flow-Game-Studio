# /flow-sponsor

Design and implement gasless transaction sponsorship for Flow games.

## Usage

- `/flow-sponsor setup` — scaffold the sponsor service and configure allowed transactions
- `/flow-sponsor add-tx <filename>` — whitelist a new transaction template for sponsorship
- `/flow-sponsor budget --monthly-txs 100000` — estimate monthly FLOW cost for sponsorship
- `/flow-sponsor audit` — review current whitelist for abuse vectors

## Flow Multi-Role Transaction Structure

```
+------------------------------------------------+
| Flow Transaction                                |
|  proposer:    player (sequence number)          |
|  payer:       STUDIO SPONSOR ACCOUNT (pays fee) |
|  authorizer:  player (account capabilities)     |
+------------------------------------------------+
```

Player signs as proposer + authorizer.
Sponsor service adds payer signature.
Player submits the fully signed transaction.

## Cost Estimation

Flow transaction fees are very low (~0.000001 FLOW per simple tx, ~0.0001 for complex).
At $1 FLOW: 100,000 sponsored txs approximately $0.10-$10 depending on tx complexity.
Budget ~$100/month for 1M sponsored transactions.

## Security Checklist

- [ ] Whitelist: only sponsor approved transaction templates (hash-checked)
- [ ] Rate limit: max N sponsored txs per player per hour (prevent drain attacks)
- [ ] Fee cap: reject transactions with estimated fee > MAX_FEE_UFIX64
- [ ] Monitoring: alert if daily spend exceeds budget threshold
- [ ] Key rotation: sponsor private key rotated every 90 days
- [ ] Separate sponsor account from admin/minter accounts

## Cadence Transaction Multi-Role Pattern

```cadence
// In sponsored transactions, the player is the authorizer.
// DO NOT access payment capabilities from the payer account —
// the payer only pays fees, nothing else.
transaction {
    prepare(player: auth(BorrowValue) &Account) {
        // Only player's account is accessed here
        // Payer account is NOT available in prepare()
    }
}
```

# Sponsored Transactions (Gasless UX)

## How Flow Multi-Role Transactions Work

Every Flow transaction has three optional signer roles:

```
proposer   = provides sequence number (prevents replay)
payer      = pays FLOW transaction fee
authorizer = provides account capabilities
```

For gasless UX, the player is the **authorizer only**. The studio is the **payer**.

## Architecture

```
[Player Client]                    [Studio Backend]              [Flow Network]
  Build tx (authorizer+proposer) →  Add payer signature       →  Execute tx
  Sign as authorizer+proposer        Sign as payer
  POST to /sponsor endpoint          Return fully signed RLP
  Submit signed tx to Flow
```

## Running the Sponsor Service

```bash
cd tools/sponsor
SPONSOR_PRIVATE_KEY=<key> SPONSOR_ADDRESS=<address> npm start
```

## Adding Allowed Transactions

1. Hash the Cadence template: `echo -n "$(cat tx.cdc)" | sha256sum`
2. Add the hash to `ALLOWED_CADENCE_HASHES` in `sponsor-service.ts`
3. Redeploy the service

## Cost Estimation

Flow transaction fees (approximate):
- Simple transfer: ~0.000001 FLOW
- Complex game transaction: ~0.0001 FLOW

At $1 FLOW:
- 1,000,000 sponsored transactions = ~$0.10 to $100

Budget approximately $100/month for casual game scale (1M daily transactions).

## Security Notes

- The sponsor service ONLY signs as payer — it has no access to player accounts
- Keep `SPONSOR_PRIVATE_KEY` in a secrets manager (AWS Secrets Manager, HashiCorp Vault)
- Never sponsor transactions that access or modify FLOW balances
- Monitor daily spend and alert if it exceeds budget threshold
- Rotate sponsor key every 90 days

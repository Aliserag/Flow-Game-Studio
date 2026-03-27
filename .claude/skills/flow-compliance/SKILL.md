# /flow-compliance

Run a compliance self-assessment for a Flow blockchain game before launch.

## THIS SKILL DOES NOT PROVIDE LEGAL ADVICE.

Output is informational only. Always consult a licensed attorney.

## Usage

```
/flow-compliance assess
/flow-compliance token-check
/flow-compliance privacy-audit
```

## assess

Runs through the pre-launch legal checklist:
1. Token classification risk (Howey test)
2. OFAC screening implementation review
3. KYC/AML requirements analysis
4. Jurisdiction blocking requirements
5. Privacy policy completeness (GDPR/CCPA)

## token-check

Reviews the GameToken contract for compliance red flags:
- Hard supply cap present? (GOOD)
- Transferable on secondary market? (RISK — flag)
- Price appreciation language in any docs? (RISK — flag)
- Direct fiat sale mechanism? (HIGH RISK — flag)
- Geographic access controls? (check)

## privacy-audit

Reviews for privacy compliance:
- Wallet addresses stored in event indexer (may be personal data under GDPR)
- Any email/username linked to wallet? (requires consent)
- Data retention policy for indexer database
- Right to deletion (blockchain is immutable — document limitation)

## Output Format

For each item: STATUS (PASS / REVIEW / BLOCK), explanation, and recommended action.

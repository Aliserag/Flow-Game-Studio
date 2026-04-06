# Privacy Policy Guide for Blockchain Games

**THIS IS NOT LEGAL ADVICE. Consult a privacy law attorney for your jurisdiction.**

## Key Privacy Considerations for Flow Games

### Wallet Addresses as Personal Data

Under GDPR, a wallet address may constitute personal data if it can be linked to an individual.
This includes addresses stored in your off-chain event indexer.

**Required actions:**
- Include wallet address handling in your privacy policy
- Establish a legal basis for processing (legitimate interest or consent)
- Document data retention periods for your SQLite indexer
- Address right-to-erasure limitations (blockchain data is immutable — document this clearly)

### On-Chain vs Off-Chain Data

| Data Type | Location | GDPR Risk |
|-----------|----------|-----------|
| NFT ownership | Flow blockchain (immutable) | MEDIUM — cannot delete |
| Game event history | Flow blockchain (immutable) | MEDIUM — cannot delete |
| Player profiles | Off-chain database | HIGH — must implement deletion |
| Email/username | Off-chain database | HIGH — must implement deletion |
| IP addresses | Server logs | HIGH — strict retention limits |

### GDPR Required Disclosures

Your privacy policy must cover:
- What data is collected (wallet address, game events, optional email)
- Why it is collected (legal basis)
- How long it is retained
- Who it is shared with (indexer vendor, analytics providers)
- Player rights: access, rectification, erasure (note blockchain limitations), portability
- Contact for privacy requests

### CCPA (California) Compliance

- Disclose categories of personal information collected
- Provide opt-out of "sale" of personal information
- Do not discriminate against users who exercise privacy rights

### Children's Privacy (COPPA/GDPR-K)

If your game may be used by children under 13 (US) or 16 (EU):
- Implement age verification
- Obtain parental consent before collecting any data
- Do NOT use behavioral advertising

## Recommended Privacy Policy Structure

1. What we collect and why
2. How we use your information
3. Blockchain and immutability notice
4. Data sharing and third parties
5. Data retention
6. Your rights
7. Children's privacy
8. Contact and data protection officer

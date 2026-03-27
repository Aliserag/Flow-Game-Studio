# /flow-launch

Pre-launch checklist for a Flow blockchain game going to mainnet.
Covers security, compliance, infrastructure, and marketing readiness.

## Checklist

### Smart Contract Security
- [ ] All contracts audited by external auditor (e.g., Kudelski, NCC Group)
- [ ] EmergencyPause deployed and admin key on hardware wallet
- [ ] No bare `auth &T` patterns (all use entitlement syntax)
- [ ] Minter key separate from admin key (principle of least privilege)
- [ ] VersionRegistry populated with deployed contract hashes
- [ ] Upgrade path tested with dummy player data on testnet

### Infrastructure
- [ ] Event indexer running on dedicated server (not local dev machine)
- [ ] IPFS metadata pinned to Pinata with redundant pinning (NFT.Storage backup)
- [ ] Testnet deploy verified — all functions work end-to-end
- [ ] Mainnet deploy dry-run completed (emulator with mainnet addresses)
- [ ] Monitoring alerts configured for contract events

### Economy
- [ ] GameToken total supply and distribution modeled (see /flow-economics-audit)
- [ ] NFT royalty percentages verified (MetadataViews.Royalties)
- [ ] Marketplace platform fee set and tested
- [ ] Treasury multisig configured (2-of-3 minimum for mainnet)

### Legal & Compliance
- [ ] Token classification opinion obtained (utility vs security — see docs/legal/)
- [ ] Terms of Service reference blockchain ownership implications
- [ ] Privacy policy covers wallet addresses as personal data (GDPR)
- [ ] OFAC screening implemented for token transfers above threshold
- [ ] Jurisdiction analysis completed for primary player markets

### Player Communication
- [ ] Wallet setup guide written (Blocto, Flow Reference Wallet, Dapper)
- [ ] NFT ownership explanation (what players actually own)
- [ ] Gas fee (FLOW) explainer in FAQ
- [ ] Known testnet bugs / limitations documented

## When invoked

Walk through each section interactively, marking items as:
- PASS: Evidence provided or explicitly confirmed
- WARN: Needs attention before launch
- BLOCK: Must be resolved before mainnet

# /flow-onboard

Interactive onboarding for a developer new to this Flow game studio.

## What This Skill Does

1. Asks 3 questions to calibrate depth:
   - "Are you new to blockchain development?"
   - "Are you new to Cadence specifically?"
   - "What is your primary role: smart contract dev, game client dev, or DevOps?"

2. Based on answers, generates a personalized onboarding path:

   **New to blockchain**: Start with conceptual overview of resources/capabilities, then Flow's ownership model vs EVM account model, then first transaction.

   **Cadence-experienced**: Skip basics, go straight to Cadence 1.0 breaking changes, then entitlements guide.

   **Game client dev**: Focus on `src/flow-bridge/` (Godot or Unity), FCL SDK, and reading NFT/token state via scripts.

   **DevOps**: Focus on CI/CD pipeline, emulator setup, testnet deploy workflow, and monitoring.

3. Generates a personalized checklist in `docs/onboarding/<name>-checklist.md`

4. Suggests which skill to run first based on their role.

## Never Assume

- Never assume the developer knows Cadence — explain resource-based ownership if they seem uncertain
- Never assume they know which wallet to use — recommend Blocto for testnet
- Always point to `docs/flow/developer-portal.md` as the canonical reference

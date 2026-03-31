# Chess on Flow

Fully playable chess game on Flow blockchain — end-to-end integration test of the Flow game studio.

**Systems exercised:** GameNFT, NFT Attachments, EmergencyPause, VRF, Sponsor Service (gasless), HybridCustody (walletless), Audio, MetadataViews.

## Quickstart (under 5 minutes)

**Prerequisites:** [Flow CLI](https://docs.onflow.org/flow-cli/install/) + Node.js 18+

```bash
# 1. Start emulator
flow emulator

# 2. Deploy contracts + create test accounts
bash tools/deploy.sh
bash tools/setup-players.sh

# 3. Install client deps + start dev server
cd client && npm install && npm run dev
# Browser opens automatically at http://localhost:5173
```

No wallet extension required (HybridCustody). No FLOW tokens required (sponsored transactions).

## Architecture

| Layer | Technology |
|-------|------------|
| Move validation | chess.js (off-chain) |
| Board state | FEN string on-chain in ChessGame |
| NFTs | 32 ChessPiece NFTs minted per game |
| Stats | ChessStatsAttachment (Cadence 1.0 attachment) |
| Gas | Sponsored — players pay zero FLOW |
| Onboarding | HybridCustody app-custodied accounts |
| Colors | VRF commit/reveal |
| Audio | Procedural Web Audio API (no files) |

## Contracts

| Contract | Purpose |
|----------|---------|
| `ChessPiece.cdc` | NFT — 32 pieces per game, full MetadataViews |
| `ChessStatsAttachment.cdc` | Cadence 1.0 attachment: moves/captures/checks per piece |
| `ChessGame.cdc` | Lifecycle: challenge → reveal → moves → endgame |

## Running Tests

```bash
npm test
```

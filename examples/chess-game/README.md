# Chess on Flow

Fully playable chess game on Flow blockchain — end-to-end integration test of the Flow game studio.

**Systems exercised:** GameNFT, NFT Attachments, EmergencyPause, VRF, Audio, MetadataViews.

## Quickstart (under 10 minutes)

**Prerequisites:** [Flow CLI](https://docs.onflow.org/flow-cli/install/) (v2.x) + Node.js 18+

**You need 4 terminal windows.** Chess requires two players — you'll connect as two different wallet accounts.

### Step 1: Start the emulator (Terminal 1)

```bash
cd examples/chess-game
flow emulator
```

### Step 2: Start the dev wallet (Terminal 2)

```bash
cd examples/chess-game
flow dev-wallet
# Dev wallet UI: http://localhost:8701
```

### Step 3: Deploy contracts (Terminal 3)

```bash
cd examples/chess-game
bash tools/deploy.sh
```

### Step 4: Start the client (Terminal 4)

```bash
cd examples/chess-game/client
npm install
npm run dev
# Opens at http://localhost:5173
```

### Step 5: Play

Open **two browser tabs** at `http://localhost:5173`.

**Tab 1 (Player 1 — Challenger):**
1. Click **Connect Wallet** → select any account in the dev wallet popup
2. Copy Player 2's address from Tab 2
3. Paste it in the opponent address field and click **Challenge Player**
4. Note the Game ID shown in the status bar

**Tab 2 (Player 2 — Opponent):**
1. Click **Connect Wallet** → select a DIFFERENT account than Tab 1
2. Enter the Game ID from Tab 1
3. Click **Accept Challenge**
4. Game starts — pieces appear on both boards

Now make moves! Each move is submitted as a transaction to the Flow emulator.

## Architecture

| Layer | Technology |
|-------|------------|
| Move validation | chess.js (off-chain) |
| Board state | FEN string on-chain in ChessGame |
| NFTs | 32 ChessPiece NFTs minted per game |
| Stats | ChessStatsAttachment (Cadence 1.0 attachment) |
| Gas | FCL wallet (sponsor payer planned) |
| Onboarding | FCL Wallet + flow dev-wallet for local testing |
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
cd examples/chess-game

# Unit + integration tests (all contracts)
flow test cadence/tests/ChessPiece_test.cdc
flow test cadence/tests/ChessGame_test.cdc

# End-to-end game lifecycle test
flow test cadence/tests/ChessGame_e2e_test.cdc
```

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Error: cannot find network emulator` | Run `flow emulator` from `examples/chess-game/` (not repo root) |
| `Contract already deployed` | Re-running `deploy.sh` is safe — `--update` flag handles already-deployed contracts |
| Connect Wallet popup doesn't appear | Ensure `flow dev-wallet` is running on port 8701 |
| `Move failed: Transaction failed` | Wallet not connected, or it's not your turn |
| Board doesn't update after opponent moves | Board polls every 3 seconds — wait or refresh |

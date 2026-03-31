# Chess on Flow — Design Spec

**Date:** 2026-03-31
**Status:** Approved
**Location:** `examples/chess-game/`
**Purpose:** End-to-end integration test of the Flow blockchain game studio infrastructure

---

## Goals

Build a fully playable chess game that exercises every major studio system:

| System | Usage |
|--------|-------|
| GameNFT | Chess pieces (32 NFTs per match) |
| NFT Attachments | Per-piece stats (moves, captures, checks) |
| EmergencyPause | Guard all state-mutating contract functions |
| Sponsored Transactions | All moves are gasless for players |
| HybridCustody | Walletless onboarding for new players |
| VRF commit/reveal | Color (white/black) assignment |
| Audio System | Move/capture/check/checkmate SFX |
| MetadataViews | Pieces show up properly in wallets |
| Event Indexer | Real-time opponent move polling |

---

## Architecture

### Move Validation Strategy: Off-chain + On-chain State Commitment

- **Client** validates all moves using `chess.js` (legal move enforcement, check detection, castling, en passant, promotion)
- **Chain** stores FEN string (board state), move history, and enforces: correct turn order, game status, piece ownership
- **Trust model:** Either player can dispute by submitting a position that `chess.js` (run deterministically) would reject — handled off-chain via signed state. For this studio context (non-financial game), this is the correct production pattern.

---

## Contracts

### `ChessPiece.cdc`
**Location:** `examples/chess-game/cadence/contracts/ChessPiece.cdc`

NFT contract. One token per piece (32 minted per match).

**Fields per NFT:**
- `id: UInt64` — unique token ID
- `pieceType: PieceType` — enum: King, Queen, Rook, Bishop, Knight, Pawn
- `color: PieceColor` — enum: White, Black
- `symbol: String` — unicode: ♔♕♖♗♘♙♚♛♜♝♞♟
- `gameId: UInt64` — which game this piece belongs to
- `startSquare: String` — initial square (e.g. "e1")

**Entitlements:** `Minter` (mint new pieces), `GameUpdater` (update stats via attachment)

**MetadataViews implemented:**
- `Display` — name ("White King"), description, thumbnail (unicode symbol)
- `Serial` — unique serial per piece type + color
- `Traits` — pieceType, color, gameId

**Storage paths:**
- `ChessPiece.CollectionStoragePath = /storage/chessCollection`
- `ChessPiece.CollectionPublicPath = /public/chessCollection`
- `ChessPiece.MinterStoragePath = /storage/chessMinter`

---

### `ChessStatsAttachment.cdc`
**Location:** `examples/chess-game/cadence/contracts/ChessStatsAttachment.cdc`

Cadence 1.0 attachment on `ChessPiece.NFT`. Travels with the piece NFT on transfer.

**Stats tracked:**
- `movesMade: UInt64` — total moves this piece has made across all games
- `capturesMade: UInt64` — pieces captured
- `timesCheckedKing: UInt64` — times this piece delivered check
- `gamesWon: UInt64` — games where owner won while this piece was active
- `gamesLost: UInt64` — games where owner lost

**Access control:**
- Read: `access(all)` — anyone can read stats (wallet display, leaderboards)
- Write: `access(GameUpdater)` — only `ChessGame` contract can increment

---

### `ChessGame.cdc`
**Location:** `examples/chess-game/cadence/contracts/ChessGame.cdc`

Game lifecycle and state.

**`Game` struct:**
```
id: UInt64
challenger: Address
opponent: Address
white: Address?          // nil until VRF reveal
black: Address?
fen: String              // current board state (FEN notation)
moveHistory: [String]    // algebraic notation list
status: GameStatus       // pending | active | checkmate | stalemate | resigned | drawn
winner: Address?
lastMoveBlock: UInt64    // for timeout detection
createdAtBlock: UInt64
```

**`GameStatus` enum:** pending, active, checkmate, stalemate, resigned, drawn, timedOut

**Public functions:**

| Function | Description |
|----------|-------------|
| `createChallenge(opponent: Address): UInt64` | Creates open challenge, returns gameId |
| `acceptChallenge(gameId: UInt64, secret: UInt256)` | VRF commit for color assignment |
| `revealColors(gameId: UInt64, secret: UInt256)` | VRF reveal → assigns colors → mints 32 pieces |
| `makeMove(gameId: UInt64, move: String, newFen: String, isCapture: Bool, isCheck: Bool)` | Validate turn + store state + update stats |
| `resign(gameId: UInt64)` | Signer resigns; opponent wins |
| `offerDraw(gameId: UInt64)` | Flag draw offer |
| `acceptDraw(gameId: UInt64)` | Accept pending draw offer |
| `claimTimeout(gameId: UInt64)` | Win by timeout if opponent hasn't moved in 1000 blocks |

**Invariants enforced on-chain:**
- Caller must be the correct player for their turn
- Game must be in `active` status for moves
- `EmergencyPause.assertNotPaused()` at top of all state-mutating functions

**Rewards:** Winner receives 100 GameTokens via stored Minter capability.

---

## Transactions

All transactions are routed through `TransactionSponsorship` — players pay zero FLOW.

| File | Description |
|------|-------------|
| `setup_chess_account.cdc` | Init ChessPiece collection + GameToken vault |
| `create_challenge.cdc` | Challenge an address by their Flow address |
| `accept_challenge.cdc` | Accept challenge + VRF commit |
| `reveal_colors.cdc` | VRF reveal → pieces minted, game starts |
| `make_move.cdc` | Submit move string + new FEN + capture/check flags |
| `resign_game.cdc` | Resign from active game |
| `offer_draw.cdc` | Offer draw to opponent |
| `accept_draw.cdc` | Accept opponent's draw offer |
| `claim_timeout.cdc` | Claim win if opponent times out |

---

## Scripts

| File | Returns |
|------|---------|
| `get_board.cdc(gameId)` | FEN string + last move + whose turn |
| `get_piece_stats.cdc(address, pieceId)` | Full `ChessStatsAttachment` data |
| `get_active_games.cdc(address)` | Array of gameIds where address is a participant |
| `get_move_history.cdc(gameId)` | Full algebraic move list |
| `get_piece_collection.cdc(address)` | All chess piece NFTs owned by address |

---

## Client

**Stack:** TypeScript + FCL + `chess.js` + Howler.js + HTML/CSS (no framework)

**Files:**
```
client/
├── package.json           # chess.js, @onflow/fcl, howler, typescript
├── tsconfig.json
├── index.html             # Single-page UI
└── src/
    ├── chess-client.ts    # FCL transaction/script wrappers
    ├── board.ts           # FEN → visual board (ASCII + HTML unicode)
    ├── audio.ts           # Chess SFX extending procedural-sfx system
    ├── sponsorship.ts     # Wraps FCL mutate with payer service
    ├── wallet.ts          # HybridCustody walletless onboarding
    └── main.ts            # App entry, event loop, UI wiring
```

**UI layout:** Board (center) + move history (right) + piece stats panel (left, shows selected piece's attachment stats) + status bar (whose turn, game status, block number)

**Move flow:**
1. Player clicks piece → valid squares highlighted (chess.js)
2. Player clicks target → `chess.js` validates, computes new FEN
3. `make_move.cdc` sent via FCL (sponsored) → emits `MoveMade` event
4. Audio fires: move sound (slide), capture sound (thud), check (ding), checkmate (fanfare)
5. Opponent's board updates via 3s polling of `get_board.cdc`

**Audio — new chess presets (extending `procedural-sfx.ts`):**
- `chess_move` — soft sliding wood sound
- `chess_capture` — sharp thud
- `chess_check` — bell ding
- `chess_checkmate` — short fanfare sequence

**Walletless onboarding (HybridCustody):**
- New players get an app-custodied Flow account on first visit (no wallet extension required)
- `wallet.ts` wraps the HybridCustody provisioning flow
- Players can later "graduate" to self-custody by linking their own wallet

---

## Developer Experience

### Directory Structure
```
examples/chess-game/
├── README.md                    # 5-minute quickstart
├── flow.json                    # Chess contract aliases + emulator config
├── package.json                 # Root: ties together cadence tests + client
├── tools/
│   ├── deploy.sh                # Deploy all contracts to emulator
│   └── setup-players.sh        # Create 2 test accounts, fund, setup collections
├── cadence/
│   ├── contracts/
│   │   ├── ChessPiece.cdc
│   │   ├── ChessStatsAttachment.cdc
│   │   └── ChessGame.cdc
│   ├── transactions/            # All 9 transactions
│   ├── scripts/                 # All 5 scripts
│   └── tests/
│       ├── ChessPiece_test.cdc
│       └── ChessGame_test.cdc
└── client/
    ├── index.html
    ├── package.json
    └── src/
```

### Quickstart (README target: under 5 minutes)
```bash
# 1. Start emulator
flow emulator &

# 2. Deploy everything + create test accounts
bash tools/deploy.sh
bash tools/setup-players.sh

# 3. Install client deps
cd client && npm install

# 4. Play
open index.html
```

No wallet extension required for first play (HybridCustody). No FLOW tokens required (sponsored transactions).

---

## Tests

**`ChessPiece_test.cdc`:**
- Mint a full set (32 pieces)
- Verify piece type, color, symbol fields
- Verify MetadataViews Display returns correct data
- Attach `ChessStatsAttachment` and verify initial zero state

**`ChessGame_test.cdc`:**
- Full game lifecycle: createChallenge → acceptChallenge → revealColors → makeMove (×5) → resign
- Verify FEN stored correctly after each move
- Verify piece stats attachment incremented on capture
- Verify EmergencyPause blocks moves when paused
- Verify timeout claim works after 1000 blocks
- Verify GameToken reward distributed to winner

---

## Systems Integration Summary

| Studio System | How Chess Uses It |
|---------------|-------------------|
| `GameNFT` pattern | `ChessPiece.cdc` follows identical entitlement structure |
| `EquipmentAttachment` pattern | `ChessStatsAttachment` uses same attachment syntax |
| `EmergencyPause` | Imported in `ChessGame.cdc`, guards all moves |
| `RandomVRF` | Color assignment via commit/reveal in accept/reveal flow |
| `TransactionSponsorship` | All 9 transactions submitted via payer service |
| `HybridCustodyManager` | `wallet.ts` provisions app-custodied accounts |
| `AudioManager` + `ProceduralSFX` | 4 new chess SFX presets wired to FCL events |
| Event indexer | Opponent move polling via `get_board.cdc` script |
| `MetadataViews` | Pieces render in any Flow-compatible wallet |

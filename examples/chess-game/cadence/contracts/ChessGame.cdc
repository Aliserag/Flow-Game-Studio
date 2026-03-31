// examples/chess-game/cadence/contracts/ChessGame.cdc
import NonFungibleToken from "NonFungibleToken"
import ChessPiece from "ChessPiece"
import ChessStatsAttachment from "ChessStatsAttachment"
import EmergencyPause from "EmergencyPause"

access(all) contract ChessGame {

    access(all) var nextGameId: UInt64

    access(all) event ChallengeCreated(gameId: UInt64, challenger: Address, opponent: Address)
    access(all) event ChallengeAccepted(gameId: UInt64, secret: UInt256)
    access(all) event ColorsRevealed(gameId: UInt64, white: Address, black: Address)
    access(all) event MoveMade(gameId: UInt64, player: Address, move: String, fen: String, isCapture: Bool, isCheck: Bool)
    access(all) event GameEnded(gameId: UInt64, status: UInt8, winner: Address?)
    access(all) event DrawOffered(gameId: UInt64, by: Address)
    access(all) event DrawAccepted(gameId: UInt64)

    access(all) let GameStoragePath: StoragePath
    access(all) let GamePublicPath: PublicPath

    access(all) enum GameStatus: UInt8 {
        access(all) case pending
        access(all) case active
        access(all) case checkmate
        access(all) case stalemate
        access(all) case resigned
        access(all) case drawn
        access(all) case timedOut
    }

    access(all) struct Game {
        access(all) let id: UInt64
        access(all) let challenger: Address
        access(all) let opponent: Address
        access(all) var white: Address?
        access(all) var black: Address?
        access(all) var fen: String
        access(all) var moveHistory: [String]
        access(all) var status: GameStatus
        access(all) var winner: Address?
        access(all) var lastMoveBlock: UInt64
        access(all) let createdAtBlock: UInt64
        access(all) var drawOfferedBy: Address?
        access(all) var vrfCommit: UInt256?

        init(id: UInt64, challenger: Address, opponent: Address) {
            self.id = id
            self.challenger = challenger
            self.opponent = opponent
            self.white = nil
            self.black = nil
            self.fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
            self.moveHistory = []
            self.status = GameStatus.pending
            self.winner = nil
            self.lastMoveBlock = getCurrentBlock().height
            self.createdAtBlock = getCurrentBlock().height
            self.drawOfferedBy = nil
            self.vrfCommit = nil
        }
    }

    access(self) var games: {UInt64: Game}

    // VRF: derive color assignment from secret
    access(self) fun assignColors(gameId: UInt64, secret: UInt256) {
        let game = self.games[gameId] ?? panic("Game not found")
        // Simple deterministic assignment: hash of secret mod 2
        let hash = secret % 2
        if hash == 0 {
            self.games[gameId]!.white = game.challenger
            self.games[gameId]!.black = game.opponent
        } else {
            self.games[gameId]!.white = game.opponent
            self.games[gameId]!.black = game.challenger
        }
    }

    // Mint all 32 pieces and deposit into each player's collection
    access(self) fun mintPiecesForGame(gameId: UInt64) {
        let game = self.games[gameId] ?? panic("Game not found")
        let white = game.white ?? panic("Colors not assigned")
        let black = game.black ?? panic("Colors not assigned")

        let minterRef = self.account.storage.borrow<auth(ChessPiece.Minter) &ChessPiece.NFTMinter>(
            from: ChessPiece.MinterStoragePath
        ) ?? panic("Cannot borrow minter")

        // Piece layout: King, Queen, 2 Rooks, 2 Bishops, 2 Knights, 8 Pawns
        let whiteLayout: [{String: AnyStruct}] = [
            {"type": ChessPiece.PieceType.King,   "sq": "e1"},
            {"type": ChessPiece.PieceType.Queen,  "sq": "d1"},
            {"type": ChessPiece.PieceType.Rook,   "sq": "a1"},
            {"type": ChessPiece.PieceType.Rook,   "sq": "h1"},
            {"type": ChessPiece.PieceType.Bishop, "sq": "c1"},
            {"type": ChessPiece.PieceType.Bishop, "sq": "f1"},
            {"type": ChessPiece.PieceType.Knight, "sq": "b1"},
            {"type": ChessPiece.PieceType.Knight, "sq": "g1"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "a2"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "b2"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "c2"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "d2"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "e2"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "f2"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "g2"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "h2"}
        ]
        let blackLayout: [{String: AnyStruct}] = [
            {"type": ChessPiece.PieceType.King,   "sq": "e8"},
            {"type": ChessPiece.PieceType.Queen,  "sq": "d8"},
            {"type": ChessPiece.PieceType.Rook,   "sq": "a8"},
            {"type": ChessPiece.PieceType.Rook,   "sq": "h8"},
            {"type": ChessPiece.PieceType.Bishop, "sq": "c8"},
            {"type": ChessPiece.PieceType.Bishop, "sq": "f8"},
            {"type": ChessPiece.PieceType.Knight, "sq": "b8"},
            {"type": ChessPiece.PieceType.Knight, "sq": "g8"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "a7"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "b7"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "c7"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "d7"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "e7"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "f7"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "g7"},
            {"type": ChessPiece.PieceType.Pawn,   "sq": "h7"}
        ]

        let whiteCollectionRef = getAccount(white)
            .capabilities.borrow<&ChessPiece.Collection>(ChessPiece.CollectionPublicPath)
            ?? panic("White player has no chess collection")
        let blackCollectionRef = getAccount(black)
            .capabilities.borrow<&ChessPiece.Collection>(ChessPiece.CollectionPublicPath)
            ?? panic("Black player has no chess collection")

        for entry in whiteLayout {
            let piece <- minterRef.mintPiece(
                pieceType: entry["type"]! as! ChessPiece.PieceType,
                color: ChessPiece.PieceColor.White,
                gameId: gameId,
                startSquare: entry["sq"]! as! String
            )
            whiteCollectionRef.deposit(token: <- piece)
        }
        for entry in blackLayout {
            let piece <- minterRef.mintPiece(
                pieceType: entry["type"]! as! ChessPiece.PieceType,
                color: ChessPiece.PieceColor.Black,
                gameId: gameId,
                startSquare: entry["sq"]! as! String
            )
            blackCollectionRef.deposit(token: <- piece)
        }
    }

    // Public game lifecycle functions

    access(all) fun createChallenge(challenger: Address, opponent: Address): UInt64 {
        EmergencyPause.assertNotPaused()
        let id = ChessGame.nextGameId
        ChessGame.nextGameId = ChessGame.nextGameId + 1
        self.games[id] = Game(id: id, challenger: challenger, opponent: opponent)
        emit ChallengeCreated(gameId: id, challenger: challenger, opponent: opponent)
        return id
    }

    access(all) fun acceptChallenge(gameId: UInt64, caller: Address, secret: UInt256) {
        EmergencyPause.assertNotPaused()
        let game = self.games[gameId] ?? panic("Game not found")
        assert(game.status == GameStatus.pending, message: "Game not pending")
        assert(caller == game.opponent, message: "Only opponent can accept")
        self.games[gameId]!.vrfCommit = secret
        emit ChallengeAccepted(gameId: gameId, secret: secret)
    }

    access(all) fun revealColors(gameId: UInt64, caller: Address, secret: UInt256) {
        EmergencyPause.assertNotPaused()
        let game = self.games[gameId] ?? panic("Game not found")
        assert(game.status == GameStatus.pending, message: "Game not pending")
        assert(caller == game.opponent, message: "Only opponent can reveal")
        assert(game.vrfCommit != nil, message: "Must accept challenge first")

        self.assignColors(gameId: gameId, secret: secret)
        self.games[gameId]!.status = GameStatus.active
        self.games[gameId]!.lastMoveBlock = getCurrentBlock().height

        let white = self.games[gameId]!.white!
        let black = self.games[gameId]!.black!
        emit ColorsRevealed(gameId: gameId, white: white, black: black)

        self.mintPiecesForGame(gameId: gameId)
    }

    access(all) fun makeMove(gameId: UInt64, caller: Address, move: String, newFen: String, isCapture: Bool, isCheck: Bool) {
        EmergencyPause.assertNotPaused()
        let game = self.games[gameId] ?? panic("Game not found")
        assert(game.status == GameStatus.active, message: "Game not active")

        // Determine whose turn it is from FEN
        let fenParts = newFen.split(separator: " ")
        // Current FEN (before move) tells us whose turn it was
        let currentFenParts = game.fen.split(separator: " ")
        let turnIndicator = currentFenParts.length > 1 ? currentFenParts[1] : "w"
        let isWhiteTurn = turnIndicator == "w"
        let expectedPlayer = isWhiteTurn ? game.white! : game.black!
        assert(caller == expectedPlayer, message: "Not your turn")

        self.games[gameId]!.fen = newFen
        self.games[gameId]!.moveHistory.append(move)
        self.games[gameId]!.lastMoveBlock = getCurrentBlock().height
        self.games[gameId]!.drawOfferedBy = nil // move cancels draw offer

        emit MoveMade(gameId: gameId, player: caller, move: move, fen: newFen, isCapture: isCapture, isCheck: isCheck)
    }

    access(all) fun endGame(gameId: UInt64, status: GameStatus, winner: Address?) {
        EmergencyPause.assertNotPaused()
        let game = self.games[gameId] ?? panic("Game not found")
        assert(game.status == GameStatus.active, message: "Game not active")
        self.games[gameId]!.status = status
        self.games[gameId]!.winner = winner
        emit GameEnded(gameId: gameId, status: status.rawValue, winner: winner)
    }

    access(all) fun resign(gameId: UInt64, caller: Address) {
        EmergencyPause.assertNotPaused()
        let game = self.games[gameId] ?? panic("Game not found")
        assert(game.status == GameStatus.active, message: "Game not active")
        assert(caller == game.challenger || caller == game.opponent, message: "Not a participant")
        let winner = caller == game.challenger ? game.opponent : game.challenger
        self.games[gameId]!.status = GameStatus.resigned
        self.games[gameId]!.winner = winner
        emit GameEnded(gameId: gameId, status: GameStatus.resigned.rawValue, winner: winner)
    }

    access(all) fun offerDraw(gameId: UInt64, caller: Address) {
        EmergencyPause.assertNotPaused()
        let game = self.games[gameId] ?? panic("Game not found")
        assert(game.status == GameStatus.active, message: "Game not active")
        assert(caller == game.challenger || caller == game.opponent, message: "Not a participant")
        self.games[gameId]!.drawOfferedBy = caller
        emit DrawOffered(gameId: gameId, by: caller)
    }

    access(all) fun acceptDraw(gameId: UInt64, caller: Address) {
        EmergencyPause.assertNotPaused()
        let game = self.games[gameId] ?? panic("Game not found")
        assert(game.status == GameStatus.active, message: "Game not active")
        assert(game.drawOfferedBy != nil, message: "No draw offer pending")
        assert(caller != game.drawOfferedBy!, message: "Cannot accept your own draw offer")
        self.games[gameId]!.status = GameStatus.drawn
        self.games[gameId]!.winner = nil
        emit DrawAccepted(gameId: gameId)
        emit GameEnded(gameId: gameId, status: GameStatus.drawn.rawValue, winner: nil)
    }

    access(all) fun claimTimeout(gameId: UInt64, caller: Address) {
        EmergencyPause.assertNotPaused()
        let game = self.games[gameId] ?? panic("Game not found")
        assert(game.status == GameStatus.active, message: "Game not active")
        assert(caller == game.challenger || caller == game.opponent, message: "Not a participant")
        let blocksElapsed = getCurrentBlock().height - game.lastMoveBlock
        assert(blocksElapsed >= 1000, message: "Timeout not reached (need 1000 blocks)")
        let winner = caller
        self.games[gameId]!.status = GameStatus.timedOut
        self.games[gameId]!.winner = winner
        emit GameEnded(gameId: gameId, status: GameStatus.timedOut.rawValue, winner: winner)
    }

    // Read-only accessors
    access(all) fun getGame(_ gameId: UInt64): Game? { return self.games[gameId] }
    access(all) fun getAllGameIds(): [UInt64] { return self.games.keys }
    access(all) fun getActiveGamesForAddress(_ addr: Address): [UInt64] {
        var result: [UInt64] = []
        for id in self.games.keys {
            let g = self.games[id]!
            if (g.challenger == addr || g.opponent == addr) && (g.status == GameStatus.active || g.status == GameStatus.pending) {
                result.append(id)
            }
        }
        return result
    }

    init() {
        self.nextGameId = 0
        self.games = {}
        self.GameStoragePath = /storage/chessGame
        self.GamePublicPath = /public/chessGame
    }
}

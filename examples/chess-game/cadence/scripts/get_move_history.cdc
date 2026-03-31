import ChessGame from "ChessGame"
access(all) fun main(gameId: UInt64): [String]? {
    return ChessGame.getGame(gameId)?.moveHistory
}

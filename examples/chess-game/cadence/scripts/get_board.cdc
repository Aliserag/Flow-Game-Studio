import ChessGame from "ChessGame"
access(all) fun main(gameId: UInt64): {String: AnyStruct}? {
    let game = ChessGame.getGame(gameId) ?? return nil
    return {
        "fen": game.fen,
        "lastMove": game.moveHistory.length > 0 ? game.moveHistory[game.moveHistory.length - 1] : "",
        "status": game.status.rawValue,
        "white": game.white,
        "black": game.black,
        "winner": game.winner
    }
}

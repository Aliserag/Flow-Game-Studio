import ChessGame from "ChessGame"
transaction(gameId: UInt64, move: String, newFen: String, isCapture: Bool, isCheck: Bool) {
    prepare(signer: auth(Storage) &Account) {
        ChessGame.makeMove(gameId: gameId, caller: signer.address, move: move, newFen: newFen, isCapture: isCapture, isCheck: isCheck)
    }
}

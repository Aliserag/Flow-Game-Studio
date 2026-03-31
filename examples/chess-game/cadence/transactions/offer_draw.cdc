import ChessGame from "ChessGame"
transaction(gameId: UInt64) {
    prepare(signer: auth(Storage) &Account) {
        ChessGame.offerDraw(gameId: gameId, caller: signer.address)
    }
}

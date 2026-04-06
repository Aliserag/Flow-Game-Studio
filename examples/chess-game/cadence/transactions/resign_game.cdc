import ChessGame from "ChessGame"
transaction(gameId: UInt64) {
    prepare(signer: auth(Storage) &Account) {
        ChessGame.resign(gameId: gameId, caller: signer.address)
    }
}

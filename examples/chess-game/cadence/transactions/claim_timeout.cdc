import ChessGame from "ChessGame"
transaction(gameId: UInt64) {
    prepare(signer: auth(Storage) &Account) {
        ChessGame.claimTimeout(gameId: gameId, caller: signer.address)
    }
}

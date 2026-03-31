import ChessGame from "ChessGame"
transaction(gameId: UInt64, secret: UInt256) {
    prepare(signer: auth(Storage) &Account) {
        ChessGame.revealColors(gameId: gameId, caller: signer.address, secret: secret)
    }
}

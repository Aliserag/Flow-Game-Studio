// examples/chess-game/cadence/transactions/create_challenge.cdc
import ChessGame from "ChessGame"

transaction(opponent: Address) {
    prepare(signer: auth(Storage) &Account) {
        let _ = ChessGame.createChallenge(challenger: signer.address, opponent: opponent)
    }
}

/// commit_flip.cdc — Submit a coin flip commitment.
///
/// Arguments:
///   commitHashHex  - hex-encoded SHA3_256(secret ++ playerAddress) — 64 chars
///   playerChoice   - true = heads, false = tails
///
/// The transaction is signed by the player; the payer can be a separate
/// sponsor service account (gasless flow).
import CoinFlip from "CoinFlip"

transaction(commitHashHex: String, playerChoice: Bool) {
    prepare(signer: &Account) {
        let hashBytes = commitHashHex.decodeHex()
        let flipId = CoinFlip.commit(
            player: signer.address,
            commitHash: hashBytes,
            playerChoice: playerChoice
        )
        log("Committed flip #".concat(flipId.toString()))
    }
}

/// reveal_flip.cdc — Reveal the secret and resolve a committed coin flip.
///
/// Arguments:
///   flipId  - UInt64 returned from commit_flip.cdc
///   secret  - UInt256 used to generate the original commitHash
///
/// Must be called at least one block after commit_flip.cdc.
import CoinFlip from "CoinFlip"

transaction(flipId: UInt64, secret: UInt256) {
    prepare(signer: &Account) {
        let won = CoinFlip.reveal(
            player: signer.address,
            flipId: flipId,
            secret: secret
        )
        log(won ? "You won!" : "Better luck next time.")
    }
}

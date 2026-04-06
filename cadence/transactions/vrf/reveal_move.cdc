// cadence/transactions/vrf/reveal_move.cdc
import "RandomVRF"

transaction(secret: UInt256, gameId: UInt64) {
    let playerAddress: Address
    prepare(signer: &Account) {
        self.playerAddress = signer.address
    }
    execute {
        let result = RandomVRF.reveal(
            secret: secret,
            gameId: gameId,
            player: self.playerAddress
        )
        log("Random result: ".concat(result.toString()))
    }
}

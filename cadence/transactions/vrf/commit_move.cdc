// cadence/transactions/vrf/commit_move.cdc
// Capture signer address in prepare — self.account does NOT exist in execute scope.
import "RandomVRF"

transaction(secret: UInt256, gameId: UInt64) {
    let playerAddress: Address
    prepare(signer: &Account) {
        self.playerAddress = signer.address
    }
    execute {
        RandomVRF.commit(
            secret: secret,
            gameId: gameId,
            player: self.playerAddress
        )
    }
}

// cadence/transactions/staking/unstake_position.cdc
// Unstake principal from a position in the Staking contract after lock period.
import "FungibleToken"
import "GameToken"
import "Staking"

transaction(positionId: UInt64) {
    let playerAddress: Address

    prepare(signer: auth(BorrowValue) &Account) {
        self.playerAddress = signer.address
    }

    execute {
        let principal <- Staking.unstake(positionId: positionId, player: self.playerAddress)
        let receiver = getAccount(self.playerAddress)
            .capabilities.get<&{FungibleToken.Receiver}>(GameToken.ReceiverPublicPath)
            .borrow() ?? panic("Player has no token receiver — run setup_token_vault.cdc first")
        receiver.deposit(from: <-principal)
        log("Unstaked position: ".concat(positionId.toString()))
    }
}

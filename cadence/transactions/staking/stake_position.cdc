// cadence/transactions/staking/stake_position.cdc
// Stake tokens in the Staking contract (position-based with lock period).
import "FungibleToken"
import "GameToken"
import "Staking"

transaction(amount: UFix64, lockBlocks: UInt64) {
    let playerAddress: Address
    let payment: @{FungibleToken.Vault}

    prepare(signer: auth(BorrowValue) &Account) {
        self.playerAddress = signer.address
        let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &GameToken.Vault>(
            from: GameToken.VaultStoragePath
        ) ?? panic("No GameToken vault")
        self.payment <- vault.withdraw(amount: amount)
    }

    execute {
        let positionId = Staking.stake(
            player: self.playerAddress,
            payment: <-self.payment,
            lockBlocks: lockBlocks
        )
        log("Staked position: ".concat(positionId.toString()))
    }
}

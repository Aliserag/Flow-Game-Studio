import "StakingPool"
import "GameToken"
import "FungibleToken"

transaction(amount: UFix64) {
    let stakerAddress: Address
    let payment: @{FungibleToken.Vault}

    prepare(signer: auth(BorrowValue) &Account) {
        self.stakerAddress = signer.address
        let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &GameToken.Vault>(
            from: GameToken.VaultStoragePath
        ) ?? panic("No GameToken vault")
        self.payment <- vault.withdraw(amount: amount)
    }

    execute {
        StakingPool.stake(staker: self.stakerAddress, payment: <-self.payment)
        log("Staked: ".concat(amount.toString()))
    }
}

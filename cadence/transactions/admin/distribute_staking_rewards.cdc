import "StakingPool"
import "GameToken"
import "FungibleToken"

// Admin manually distributes fee revenue to stakers
// In production, this is called by the Marketplace contract automatically
transaction(amount: UFix64) {

    let adminRef: auth(StakingPool.StakingAdmin) &StakingPool.Admin
    let payment: @{FungibleToken.Vault}

    prepare(signer: auth(BorrowValue) &Account) {
        self.adminRef = signer.storage.borrow<auth(StakingPool.StakingAdmin) &StakingPool.Admin>(
            from: StakingPool.AdminStoragePath
        ) ?? panic("No StakingPool.Admin in storage")

        let vault = signer.storage.borrow<auth(FungibleToken.Withdraw) &GameToken.Vault>(
            from: GameToken.VaultStoragePath
        ) ?? panic("No GameToken vault")
        self.payment <- vault.withdraw(amount: amount)
    }

    execute {
        self.adminRef.distributeRewards(payment: <-self.payment)
        log("Distributed rewards: ".concat(amount.toString()))
    }
}

// cadence/transactions/staking/fund_yield_pool.cdc
//
// Fund the Staking yield pool. Callable by anyone.
// Typically called by the game deployer to seed the pool before going live.
import "FungibleToken"
import "GameToken"
import "Staking"

transaction(amount: UFix64) {

    prepare(funder: auth(Storage) &Account) {
        // Borrow funder's GameToken vault with Withdraw entitlement
        let vault = funder.storage.borrow<auth(FungibleToken.Withdraw) &GameToken.Vault>(
            from: GameToken.VaultStoragePath
        ) ?? panic("No GameToken vault found — run setup_token_vault.cdc first")

        let payment <- vault.withdraw(amount: amount)
        Staking.fundYieldPool(payment: <- payment)
    }
}

// cadence/transactions/staking/stake_tokens.cdc
//
// Stake GameTokens in the Staking contract for a specified lock period (in blocks).
// Tokens are escrowed until unstake() is called after the lock expires.
import "FungibleToken"
import "GameToken"
import "Staking"

transaction(amount: UFix64, lockBlocks: UInt64) {

    prepare(player: auth(Storage) &Account) {
        // Borrow the player's GameToken vault with Withdraw entitlement
        let vault = player.storage.borrow<auth(FungibleToken.Withdraw) &GameToken.Vault>(
            from: GameToken.VaultStoragePath
        ) ?? panic("No GameToken vault found — run setup_token_vault.cdc first")

        // Withdraw the stake amount and pass to the contract
        let payment <- vault.withdraw(amount: amount)
        let positionId = Staking.stake(
            player: player.address,
            payment: <- payment,
            lockBlocks: lockBlocks
        )
        // positionId returned for caller reference (logged in event)
        let _ = positionId
    }
}

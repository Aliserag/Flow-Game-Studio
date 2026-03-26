// cadence/transactions/staking/unstake_tokens.cdc
//
// Unstake tokens for a given position. Lock period must have elapsed.
// Returns principal to signer's GameToken vault.
import "FungibleToken"
import "GameToken"
import "Staking"

transaction(positionId: UInt64) {

    prepare(player: auth(Storage) &Account) {
        // Borrow player's vault for the return deposit
        let vault = player.storage.borrow<&GameToken.Vault>(
            from: GameToken.VaultStoragePath
        ) ?? panic("No GameToken vault found — run setup_token_vault.cdc first")

        // Unstake returns the principal vault
        let principal <- Staking.unstake(
            positionId: positionId,
            player: player.address
        )

        // Deposit principal back into player's wallet
        vault.deposit(from: <- principal)
    }
}

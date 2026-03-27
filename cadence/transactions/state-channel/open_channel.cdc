// open_channel.cdc
// Opens a state channel between two players by depositing GameToken escrow.
// Both players must sign this transaction (multi-sig).

import "FungibleToken"
import "GameToken"
import "StateChannel"

transaction(playerB: Address, amountA: UFix64, amountB: UFix64) {
    prepare(playerA: auth(Storage) &Account) {
        // Withdraw playerA's deposit from their vault
        let vaultA = playerA.storage.borrow<auth(FungibleToken.Withdraw) &GameToken.Vault>(
            from: GameToken.VaultStoragePath
        ) ?? panic("No GameToken vault")

        let depositA <- vaultA.withdraw(amount: amountA)

        // PlayerB deposit is handled via a separate auth capability in multi-sig
        // For single-sig demo: deposit 0.0 for B (B would co-sign in production)
        let depositB <- GameToken.createEmptyVault(vaultType: Type<@GameToken.Vault>())

        let channelId = StateChannel.openChannel(
            playerA: playerA.address,
            playerB: playerB,
            depositA: <-depositA,
            depositB: <-depositB
        )

        log("State channel opened: ".concat(channelId.toString()))
    }
}

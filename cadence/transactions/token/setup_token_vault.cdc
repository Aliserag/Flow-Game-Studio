import "FungibleToken"
import "GameToken"

// Sets up a GameToken vault for a new account.
// Publishes both the receiver capability (for deposits) and the vault capability (for balance queries).
transaction {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        if signer.storage.borrow<&GameToken.Vault>(from: GameToken.VaultStoragePath) != nil { return }
        signer.storage.save(<- GameToken.createEmptyVault(vaultType: Type<@GameToken.Vault>()), to: GameToken.VaultStoragePath)

        // Publish receiver capability so others can deposit tokens
        let receiverCap = signer.capabilities.storage.issue<&GameToken.Vault>(GameToken.VaultStoragePath)
        signer.capabilities.publish(receiverCap, at: GameToken.ReceiverPublicPath)

        // Publish vault capability so balance can be queried
        let vaultCap = signer.capabilities.storage.issue<&GameToken.Vault>(GameToken.VaultStoragePath)
        signer.capabilities.publish(vaultCap, at: GameToken.VaultPublicPath)
    }
}

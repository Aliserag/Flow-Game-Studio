import "FungibleToken"
import "GameToken"

transaction(recipient: Address, amount: UFix64) {
    let senderVault: auth(FungibleToken.Withdraw) &GameToken.Vault
    let receiverRef: &{FungibleToken.Receiver}
    prepare(signer: auth(Storage) &Account) {
        self.senderVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &GameToken.Vault>(
            from: GameToken.VaultStoragePath
        ) ?? panic("No token vault found")
        self.receiverRef = getAccount(recipient)
            .capabilities.get<&{FungibleToken.Receiver}>(GameToken.ReceiverPublicPath)
            .borrow() ?? panic("Recipient has no token vault")
    }
    execute {
        let tokens <- self.senderVault.withdraw(amount: amount)
        self.receiverRef.deposit(from: <- tokens)
    }
}

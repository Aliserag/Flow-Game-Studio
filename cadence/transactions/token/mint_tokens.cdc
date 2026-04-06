import "FungibleToken"
import "GameToken"

transaction(recipient: Address, amount: UFix64) {
    let minter: auth(GameToken.MintTokens) &GameToken.Minter
    let receiverRef: &{FungibleToken.Receiver}
    prepare(deployer: auth(Storage) &Account) {
        self.minter = deployer.storage.borrow<auth(GameToken.MintTokens) &GameToken.Minter>(
            from: GameToken.MinterStoragePath
        ) ?? panic("No minter found")
        self.receiverRef = getAccount(recipient)
            .capabilities.get<&{FungibleToken.Receiver}>(GameToken.ReceiverPublicPath)
            .borrow() ?? panic("Recipient has no token vault")
    }
    execute {
        self.minter.mintToRecipient(amount: amount, recipient: self.receiverRef)
    }
}

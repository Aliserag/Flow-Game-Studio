// cadence/transactions/nft/transfer_nft.cdc
import "NonFungibleToken"
import "GameNFT"

transaction(nftId: UInt64, recipient: Address) {
    let senderCollection: auth(NonFungibleToken.Withdraw) &GameNFT.Collection
    let recipientCollection: &{NonFungibleToken.Collection}
    prepare(sender: auth(Storage) &Account) {
        self.senderCollection = sender.storage.borrow<auth(NonFungibleToken.Withdraw) &GameNFT.Collection>(
            from: GameNFT.CollectionStoragePath
        ) ?? panic("Sender has no NFT collection")
        self.recipientCollection = getAccount(recipient)
            .capabilities.get<&{NonFungibleToken.Collection}>(GameNFT.CollectionPublicPath)
            .borrow() ?? panic("Recipient has no NFT collection — run setup_account.cdc first")
    }
    execute {
        let nft <- self.senderCollection.withdraw(withdrawID: nftId)
        self.recipientCollection.deposit(token: <- nft)
    }
}

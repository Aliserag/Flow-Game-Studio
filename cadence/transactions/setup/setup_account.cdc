// cadence/transactions/setup/setup_account.cdc
// Initializes a player account with a GameNFT collection.
// Must be run once per player before they can receive NFTs.
import "NonFungibleToken"
import "GameNFT"

transaction {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Skip if already set up
        if signer.storage.borrow<&GameNFT.Collection>(
            from: GameNFT.CollectionStoragePath
        ) != nil {
            return
        }

        let collection <- GameNFT.createEmptyCollection(
            nftType: Type<@GameNFT.NFT>()
        )
        signer.storage.save(<- collection, to: GameNFT.CollectionStoragePath)

        let cap = signer.capabilities.storage.issue<&GameNFT.Collection>(
            GameNFT.CollectionStoragePath
        )
        signer.capabilities.publish(cap, at: GameNFT.CollectionPublicPath)
    }
}

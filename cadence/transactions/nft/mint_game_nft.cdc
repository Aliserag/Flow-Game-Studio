// cadence/transactions/nft/mint_game_nft.cdc
// Mints a GameNFT to a recipient. Must be signed by the deployer account
// that holds the Minter resource.
import "NonFungibleToken"
import "GameNFT"

transaction(recipient: Address, name: String, description: String, imageURL: String) {
    let minter: &GameNFT.Minter

    prepare(deployer: auth(Storage) &Account) {
        self.minter = deployer.storage.borrow<&GameNFT.Minter>(
            from: GameNFT.MinterStoragePath
        ) ?? panic("No GameNFT Minter found in deployer storage")
    }

    execute {
        let recipientCollection = getAccount(recipient)
            .capabilities.get<&{NonFungibleToken.Collection}>(GameNFT.CollectionPublicPath)
            .borrow() ?? panic("Recipient has no NFT collection — run setup_account.cdc first")

        self.minter.mintNFT(
            name: name,
            description: description,
            imageURL: imageURL,
            recipient: recipientCollection
        )
    }
}

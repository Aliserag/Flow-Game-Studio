// cadence/transactions/nft/batch_mint.cdc
// Mints multiple NFTs in a single transaction — essential for game launches.
// Flow transactions are atomic: all mint or none do.
import "NonFungibleToken"
import "GameNFT"

transaction(
    names: [String],
    descriptions: [String],
    imageURLs: [String],
    recipient: Address
) {
    let minter: &GameNFT.Minter
    let recipientCollection: &{NonFungibleToken.Collection}
    prepare(deployer: auth(Storage) &Account) {
        pre {
            names.length == descriptions.length && names.length == imageURLs.length:
                "All arrays must have equal length"
            names.length <= 100: "Batch size capped at 100 per transaction"
        }
        self.minter = deployer.storage.borrow<&GameNFT.Minter>(from: GameNFT.MinterStoragePath)
            ?? panic("Minter not found")
        self.recipientCollection = getAccount(recipient)
            .capabilities.get<&{NonFungibleToken.Collection}>(GameNFT.CollectionPublicPath)
            .borrow() ?? panic("Recipient has no NFT collection")
    }
    execute {
        var i = 0
        while i < names.length {
            self.minter.mintNFT(
                name: names[i],
                description: descriptions[i],
                imageURL: imageURLs[i],
                recipient: self.recipientCollection
            )
            i = i + 1
        }
    }
}

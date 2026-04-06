# Flow Standard Contracts Reference

## NonFungibleToken v2 (Cadence 1.0)

**Testnet**: `0x631e88ae7f1d7c20`
**Mainnet**: `0x1d7e57aa55817448`

### Required interfaces

```cadence
import "NonFungibleToken"

access(all) contract GameNFT: NonFungibleToken {

    access(all) resource NFT: NonFungibleToken.NFT {
        access(all) let id: UInt64
        access(all) fun getViews(): [Type]
        access(all) fun resolveView(_ view: Type): AnyStruct?
        init(id: UInt64) { self.id = id }
    }

    access(all) resource Collection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT}
        access(all) fun deposit(token: @{NonFungibleToken.NFT})
        access(all) fun getIDs(): [UInt64]
        access(all) fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}?
        access(all) fun getSupportedNFTTypes(): {Type: Bool}
        access(all) fun isSupportedNFTType(type: Type): Bool
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection}
    }

    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection}
}
```

## MetadataViews

```cadence
import "MetadataViews"

// Implement in your NFT.resolveView()
access(all) fun resolveView(_ view: Type): AnyStruct? {
    switch view {
        case Type<MetadataViews.Display>():
            return MetadataViews.Display(
                name: self.name,
                description: self.description,
                thumbnail: MetadataViews.HTTPFile(url: self.imageURL)
            )
        case Type<MetadataViews.NFTCollectionData>():
            return MetadataViews.NFTCollectionData(
                storagePath: GameNFT.CollectionStoragePath,
                publicPath: GameNFT.CollectionPublicPath,
                publicCollection: Type<&GameNFT.Collection>(),
                publicLinkedType: Type<&GameNFT.Collection>(),
                createEmptyCollectionFunction: fun(): @{NonFungibleToken.Collection} {
                    return <- GameNFT.createEmptyCollection(nftType: Type<@GameNFT.NFT>())
                }
            )
    }
    return nil
}
```

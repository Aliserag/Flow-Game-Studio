// cadence/contracts/core/GameNFT.cdc
import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"

/// GameNFT — base NFT contract for Flow game studios.
/// Cadence 1.0: uses entitlements for access control.
/// Extend this contract per-game; do not modify core logic here.
access(all) contract GameNFT: NonFungibleToken, ViewResolver {

    // -----------------------------------------------------------------------
    // Entitlements
    // -----------------------------------------------------------------------
    /// NFTMinter entitlement — held only by the Minter resource at deployer storage.
    access(all) entitlement NFTMinter
    /// Updater entitlement — allows metadata updates on an NFT.
    access(all) entitlement Updater

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    access(all) event ContractInitialized()
    access(all) event Minted(id: UInt64, name: String, to: Address?)

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    access(all) var totalSupply: UInt64

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    // -----------------------------------------------------------------------
    // NFT Resource
    // -----------------------------------------------------------------------
    access(all) resource NFT: NonFungibleToken.NFT {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let description: String
        access(all) var imageURL: String
        access(all) var metadata: {String: AnyStruct}

        /// Default destroy event required by NonFungibleToken.NFT interface
        access(all) event ResourceDestroyed(id: UInt64 = self.id, uuid: UInt64 = self.uuid)

        /// Only callable via auth(Updater) reference
        access(Updater) fun updateMetadata(key: String, value: AnyStruct) {
            self.metadata[key] = value
        }

        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionData>()
            ]
        }

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
                            return <- GameNFT.createEmptyCollection(
                                nftType: Type<@GameNFT.NFT>()
                            )
                        }
                    )
            }
            return nil
        }

        /// Required by NonFungibleToken.NFT interface in v2
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- GameNFT.createEmptyCollection(nftType: Type<@GameNFT.NFT>())
        }

        init(id: UInt64, name: String, description: String, imageURL: String) {
            self.id = id
            self.name = name
            self.description = description
            self.imageURL = imageURL
            self.metadata = {}
        }
    }

    // -----------------------------------------------------------------------
    // Collection
    // -----------------------------------------------------------------------
    access(all) resource Collection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        /// Default destroy event required by NonFungibleToken.Collection interface
        access(all) event ResourceDestroyed(uuid: UInt64 = self.uuid)

        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("GameNFT.Collection: NFT with ID ".concat(withdrawID.toString()).concat(" not found"))
            return <- token
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let id = token.id
            let old <- self.ownedNFTs[id] <- token
            destroy old
        }

        access(all) view fun getIDs(): [UInt64] { return self.ownedNFTs.keys }

        access(all) view fun getLength(): Int { return self.ownedNFTs.length }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            return {Type<@GameNFT.NFT>(): true}
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@GameNFT.NFT>()
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- GameNFT.createEmptyCollection(nftType: Type<@GameNFT.NFT>())
        }

        init() { self.ownedNFTs <- {} }
    }

    // -----------------------------------------------------------------------
    // Minter — stored by deployer, never published publicly
    // -----------------------------------------------------------------------
    access(all) resource Minter {
        access(all) fun mintNFT(
            name: String,
            description: String,
            imageURL: String,
            recipient: &{NonFungibleToken.Collection}
        ) {
            let id = GameNFT.totalSupply
            let nft <- create NFT(
                id: id,
                name: name,
                description: description,
                imageURL: imageURL
            )
            GameNFT.totalSupply = GameNFT.totalSupply + 1
            emit Minted(id: id, name: name, to: recipient.owner?.address)
            recipient.deposit(token: <- nft)
        }
    }

    // -----------------------------------------------------------------------
    // Contract functions (ViewResolver conformance)
    // -----------------------------------------------------------------------
    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [Type<MetadataViews.NFTCollectionData>()]
    }

    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
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

    // -----------------------------------------------------------------------
    // Init
    // -----------------------------------------------------------------------
    init() {
        self.totalSupply = 0
        self.CollectionStoragePath = /storage/GameNFTCollection
        self.CollectionPublicPath = /public/GameNFTCollection
        self.MinterStoragePath = /storage/GameNFTMinter

        self.account.storage.save(<- create Minter(), to: self.MinterStoragePath)
        emit ContractInitialized()
    }
}

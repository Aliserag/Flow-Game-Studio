// cadence/contracts/core/GameNFT.cdc
import "NonFungibleToken"
import "MetadataViews"

/// GameNFT — base NFT contract for Flow game studios.
/// Cadence 1.0: uses entitlements for access control.
/// Extend this contract per-game; do not modify core logic here.
access(all) contract GameNFT: NonFungibleToken {

    // -----------------------------------------------------------------------
    // Entitlements
    // -----------------------------------------------------------------------
    access(all) entitlement Minter
    access(all) entitlement Updater

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    access(all) event ContractInitialized()
    access(all) event Withdraw(id: UInt64, from: Address?)
    access(all) event Deposit(id: UInt64, to: Address?)
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

        /// Only callable via auth(Updater) reference
        access(Updater) fun updateMetadata(key: String, value: AnyStruct) {
            self.metadata[key] = value
        }

        access(all) fun getViews(): [Type] {
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

        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("GameNFT.Collection: NFT with ID ".concat(withdrawID.toString()).concat(" not found"))
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let id = token.id
            let old <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            destroy old
        }

        access(all) fun getIDs(): [UInt64] { return self.ownedNFTs.keys }

        access(all) fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        access(all) fun getSupportedNFTTypes(): {Type: Bool} {
            return {Type<@GameNFT.NFT>(): true}
        }

        access(all) fun isSupportedNFTType(type: Type): Bool {
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
    // Contract functions
    // -----------------------------------------------------------------------
    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
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

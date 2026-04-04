// PowerUp.cdc — Attachment NFT that boosts a Fighter's stats.
//
// Two separate components:
// 1. PowerUp.NFT — a standalone NFT held in a collection.
//    Stores power-up data. Can be withdrawn and consumed to create a Boost on a Fighter.
// 2. PowerUp.Boost — a Cadence `attachment` for NonFungibleToken.NFT.
//    Travels with the Fighter when transferred. Fighter.effectivePower() reads it.
//
// IMPORTANT: Cadence attachments can ONLY be created inside an `attach` expression
// (`attach PowerUp.Boost(...) to nft`). They cannot be constructed separately or returned
// as values. The attach_powerup.cdc transaction reads data from the PowerUp.NFT and then
// attaches Boost directly.
//
// Flow: mint PowerUp.NFT → withdraw from collection → read data →
//       `attach PowerUp.Boost(...) to fighter` → destroy PowerUp.NFT
//
// After attachment: `fighter[PowerUp.Boost]` returns an optional reference.

import NonFungibleToken from "NonFungibleToken"
import MetadataViews from "MetadataViews"
import ViewResolver from "ViewResolver"

access(all) contract PowerUp: NonFungibleToken, ViewResolver {

    // Entitlement held by the contract's Minter resource
    access(all) entitlement PowerUpMinter

    access(all) var totalSupply: UInt64

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    // Fired when a new PowerUp NFT is minted
    access(all) event Minted(id: UInt64, name: String, powerUpType: UInt8, bonusPower: UInt64, to: Address?)
    // Fired when a PowerUp NFT is consumed and attached to a Fighter
    access(all) event Consumed(powerUpId: UInt64, powerUpName: String)
    access(all) event ContractInitialized()

    // PowerUp types — each synergizes with a matching combat class (Gem boosts all)
    access(all) enum PowerUpType: UInt8 {
        access(all) case sword      // 0 — synergy with Attack fighters
        access(all) case shield     // 1 — synergy with Defense fighters
        access(all) case spellbook  // 2 — synergy with Magic fighters
        access(all) case gem        // 3 — boosts all classes
    }

    // The Boost attachment — attaches to any NonFungibleToken.NFT.
    // Fighter.effectivePower() reads this via self[PowerUp.Boost] to get bonusPower.
    //
    // Cadence rule: attachments can ONLY be created via `attach Boost(...) to nft`.
    // They cannot be stored, passed as values, or returned from functions.
    access(all) attachment Boost for NonFungibleToken.NFT {
        access(all) let powerUpId: UInt64
        access(all) let powerUpType: PowerUpType
        access(all) let bonusPower: UInt64
        access(all) let name: String

        init(
            powerUpId: UInt64,
            powerUpType: PowerUpType,
            bonusPower: UInt64,
            name: String
        ) {
            self.powerUpId = powerUpId
            self.powerUpType = powerUpType
            self.bonusPower = bonusPower
            self.name = name
        }

        // Returns the power-up type name for display
        access(all) view fun typeName(): String {
            switch self.powerUpType {
                case PowerUpType.sword:     return "Sword"
                case PowerUpType.shield:    return "Shield"
                case PowerUpType.spellbook: return "Spellbook"
                case PowerUpType.gem:       return "Gem"
            }
            return "Unknown"
        }
    }

    // Standalone PowerUp NFT — holds the data before the Boost is attached to a Fighter.
    // When the user attaches this to a Fighter, the NFT is destroyed and its data lives
    // in the Boost attachment on the Fighter.
    access(all) resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver {

        access(all) let id: UInt64
        access(all) let name: String
        access(all) let powerUpType: PowerUpType
        access(all) let bonusPower: UInt64

        access(all) event ResourceDestroyed(id: UInt64 = self.id, uuid: UInt64 = self.uuid)

        init(
            id: UInt64,
            name: String,
            powerUpType: PowerUpType,
            bonusPower: UInt64
        ) {
            self.id = id
            self.name = name
            self.powerUpType = powerUpType
            self.bonusPower = bonusPower
        }

        // Returns the power-up type name for display
        access(all) view fun typeName(): String {
            switch self.powerUpType {
                case PowerUpType.sword:     return "Sword"
                case PowerUpType.shield:    return "Shield"
                case PowerUpType.spellbook: return "Spellbook"
                case PowerUpType.gem:       return "Gem"
            }
            return "Unknown"
        }

        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.NFTCollectionData>()
            ]
        }

        access(all) view fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: "A "
                            .concat(self.typeName())
                            .concat(" power-up granting +")
                            .concat(self.bonusPower.toString())
                            .concat(" power when attached to a Fighter"),
                        thumbnail: MetadataViews.HTTPFile(
                            url: "https://nft-battler.example/powerups/".concat(self.id.toString())
                        )
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.id)
                case Type<MetadataViews.Traits>():
                    let traits: [MetadataViews.Trait] = [
                        MetadataViews.Trait(name: "powerUpType", value: self.typeName(), displayType: "String", rarity: nil),
                        MetadataViews.Trait(name: "bonusPower", value: self.bonusPower, displayType: "Number", rarity: nil)
                    ]
                    return MetadataViews.Traits(traits)
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: PowerUp.CollectionStoragePath,
                        publicPath: PowerUp.CollectionPublicPath,
                        publicCollection: Type<&PowerUp.Collection>(),
                        publicLinkedType: Type<&PowerUp.Collection>(),
                        createEmptyCollectionFunction: fun(): @{NonFungibleToken.Collection} {
                            return <- PowerUp.createEmptyCollection(nftType: Type<@PowerUp.NFT>())
                        }
                    )
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- PowerUp.createEmptyCollection(nftType: Type<@PowerUp.NFT>())
        }
    }

    // PowerUp Collection — stores PowerUp NFTs before they are consumed to boost Fighters
    access(all) resource Collection: NonFungibleToken.Collection {

        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init() {
            self.ownedNFTs <- {}
        }

        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("PowerUp.Collection.withdraw: NFT "
                    .concat(withdrawID.toString())
                    .concat(" not found"))
            return <- token
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let powerUp <- token as! @PowerUp.NFT
            self.ownedNFTs[powerUp.id] <-! powerUp
        }

        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        access(all) view fun getLength(): Int {
            return self.ownedNFTs.length
        }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        // Borrow a typed PowerUp.NFT reference for reading data before attachment
        access(all) view fun borrowPowerUpNFT(id: UInt64): &PowerUp.NFT? {
            let ref = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}?
            return ref as! &PowerUp.NFT?
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            return {Type<@PowerUp.NFT>(): true}
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@PowerUp.NFT>()
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- PowerUp.createEmptyCollection(nftType: Type<@PowerUp.NFT>())
        }
    }

    // Minter resource — stored at deployer account, used by mint_powerup.cdc
    access(all) resource Minter {

        access(PowerUpMinter) fun mint(
            name: String,
            powerUpType: PowerUpType,
            bonusPower: UInt64
        ): @PowerUp.NFT {
            let id = PowerUp.totalSupply
            PowerUp.totalSupply = PowerUp.totalSupply + 1
            let nft <- create NFT(
                id: id,
                name: name,
                powerUpType: powerUpType,
                bonusPower: bonusPower
            )
            emit Minted(id: id, name: name, powerUpType: powerUpType.rawValue, bonusPower: bonusPower, to: nil)
            return <- nft
        }
    }

    // Emit the Consumed event when a PowerUp NFT is about to be destroyed
    // Called from attach_powerup.cdc before destroying the NFT shell
    access(all) fun emitConsumed(powerUpId: UInt64, powerUpName: String) {
        emit Consumed(powerUpId: powerUpId, powerUpName: powerUpName)
    }

    // Contract-level createEmptyCollection — required by NonFungibleToken interface
    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    // ViewResolver contract-level implementations
    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [Type<MetadataViews.NFTCollectionData>()]
    }

    access(all) view fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                    storagePath: PowerUp.CollectionStoragePath,
                    publicPath: PowerUp.CollectionPublicPath,
                    publicCollection: Type<&PowerUp.Collection>(),
                    publicLinkedType: Type<&PowerUp.Collection>(),
                    createEmptyCollectionFunction: fun(): @{NonFungibleToken.Collection} {
                        return <- PowerUp.createEmptyCollection(nftType: Type<@PowerUp.NFT>())
                    }
                )
        }
        return nil
    }

    init() {
        self.totalSupply = 0
        self.CollectionStoragePath = /storage/powerUpCollection
        self.CollectionPublicPath = /public/powerUpCollection
        self.MinterStoragePath = /storage/powerUpMinter

        let minter <- create Minter()
        self.account.storage.save(<- minter, to: self.MinterStoragePath)

        let collection <- create Collection()
        self.account.storage.save(<- collection, to: self.CollectionStoragePath)
        let cap = self.account.capabilities.storage.issue<&PowerUp.Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(cap, at: self.CollectionPublicPath)

        emit ContractInitialized()
    }
}

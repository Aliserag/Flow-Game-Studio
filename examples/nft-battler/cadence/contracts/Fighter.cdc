// Fighter.cdc — NFT with base combat stats.
// Implements NonFungibleToken. Battle stats come from base + any attached PowerUp bonuses.
//
// Combat class determines RPS interaction:
//   Attack (0) beats Defense (1)
//   Defense (1) beats Magic (2)
//   Magic (2) beats Attack (0)
//   Same class → higher effectivePower wins; exact tie → challenger wins
//
// The PowerUp.Boost attachment is read via self[PowerUp.Boost] for bonus power.
// recordResult() is gated by NonFungibleToken.Update entitlement — only code that
// already has Update access to the collection can call it.

import NonFungibleToken from "NonFungibleToken"
import MetadataViews from "MetadataViews"
import ViewResolver from "ViewResolver"
import PowerUp from "PowerUp"

access(all) contract Fighter: NonFungibleToken, ViewResolver {

    // Entitlement held by the contract's Minter resource
    access(all) entitlement FighterMinter

    access(all) var totalSupply: UInt64

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    // Fired when a new Fighter NFT is minted
    access(all) event Minted(id: UInt64, name: String, combatClass: UInt8, basePower: UInt64, to: Address?)
    // Fired when a Fighter participates in a battle
    access(all) event Battled(fighterId: UInt64, won: Bool, opponentId: UInt64)
    access(all) event ContractInitialized()

    // Combat class — determines RPS outcome
    access(all) enum CombatClass: UInt8 {
        access(all) case attack    // 0
        access(all) case defense   // 1
        access(all) case magic     // 2
    }

    // Fighter NFT resource
    access(all) resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver {

        access(all) let id: UInt64
        access(all) let name: String
        access(all) let combatClass: CombatClass
        access(all) let basePower: UInt64   // 1–100

        // Mutable battle record — updated via NonFungibleToken.Update entitlement
        access(all) var wins: UInt64
        access(all) var losses: UInt64

        access(all) event ResourceDestroyed(id: UInt64 = self.id, uuid: UInt64 = self.uuid)

        init(id: UInt64, name: String, combatClass: CombatClass, basePower: UInt64) {
            self.id = id
            self.name = name
            self.combatClass = combatClass
            self.basePower = basePower
            self.wins = 0
            self.losses = 0
        }

        // Record a battle result — requires NonFungibleToken.Update entitlement.
        // This is the same entitlement used by collection.withdraw, ensuring only the
        // owner's authorized code (BattleArena via battle.cdc) can update the record.
        access(NonFungibleToken.Update) fun recordResult(won: Bool, opponentId: UInt64) {
            if won {
                self.wins = self.wins + 1
            } else {
                self.losses = self.losses + 1
            }
            emit Battled(fighterId: self.id, won: won, opponentId: opponentId)
        }

        // Effective power = basePower + any PowerUp.Boost bonus.
        // Reads the Boost attachment if present via self[PowerUp.Boost].
        access(all) view fun effectivePower(): UInt64 {
            var bonus: UInt64 = 0
            if let boostRef = self[PowerUp.Boost] {
                bonus = boostRef.bonusPower
            }
            return self.basePower + bonus
        }

        // Returns the combat class name for display
        access(all) view fun combatClassName(): String {
            switch self.combatClass {
                case CombatClass.attack:  return "Attack"
                case CombatClass.defense: return "Defense"
                case CombatClass.magic:   return "Magic"
            }
            return "Unknown"
        }

        // MetadataViews conformance
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
                            .concat(self.combatClassName())
                            .concat(" class fighter with ")
                            .concat(self.basePower.toString())
                            .concat(" base power. Record: ")
                            .concat(self.wins.toString())
                            .concat("W-")
                            .concat(self.losses.toString())
                            .concat("L"),
                        thumbnail: MetadataViews.HTTPFile(
                            url: "https://nft-battler.example/fighters/".concat(self.id.toString())
                        )
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.id)
                case Type<MetadataViews.Traits>():
                    let traits: [MetadataViews.Trait] = [
                        MetadataViews.Trait(name: "combatClass", value: self.combatClassName(), displayType: "String", rarity: nil),
                        MetadataViews.Trait(name: "basePower", value: self.basePower, displayType: "Number", rarity: nil),
                        MetadataViews.Trait(name: "effectivePower", value: self.effectivePower(), displayType: "Number", rarity: nil),
                        MetadataViews.Trait(name: "wins", value: self.wins, displayType: "Number", rarity: nil),
                        MetadataViews.Trait(name: "losses", value: self.losses, displayType: "Number", rarity: nil)
                    ]
                    return MetadataViews.Traits(traits)
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: Fighter.CollectionStoragePath,
                        publicPath: Fighter.CollectionPublicPath,
                        publicCollection: Type<&Fighter.Collection>(),
                        publicLinkedType: Type<&Fighter.Collection>(),
                        createEmptyCollectionFunction: fun(): @{NonFungibleToken.Collection} {
                            return <- Fighter.createEmptyCollection(nftType: Type<@Fighter.NFT>())
                        }
                    )
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- Fighter.createEmptyCollection(nftType: Type<@Fighter.NFT>())
        }
    }

    // Fighter Collection — stores Fighter NFTs for a player
    access(all) resource Collection: NonFungibleToken.Collection {

        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init() {
            self.ownedNFTs <- {}
        }

        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("Fighter.Collection.withdraw: NFT "
                    .concat(withdrawID.toString())
                    .concat(" not found"))
            return <- token
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let fighter <- token as! @Fighter.NFT
            self.ownedNFTs[fighter.id] <-! fighter
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

        // Borrow a typed Fighter reference — for scripts and read-only use
        access(all) view fun borrowFighterNFT(id: UInt64): &Fighter.NFT? {
            let ref = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}?
            return ref as! &Fighter.NFT?
        }

        // Borrow a NonFungibleToken.Update-entitled Fighter ref — used by BattleArena
        // via the battle.cdc transaction which borrows the collection with Update entitlement
        access(NonFungibleToken.Update) fun borrowFighterForBattle(id: UInt64): auth(NonFungibleToken.Update) &Fighter.NFT? {
            let ref = &self.ownedNFTs[id] as auth(NonFungibleToken.Update) &{NonFungibleToken.NFT}?
            return ref as! auth(NonFungibleToken.Update) &Fighter.NFT?
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            return {Type<@Fighter.NFT>(): true}
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@Fighter.NFT>()
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- Fighter.createEmptyCollection(nftType: Type<@Fighter.NFT>())
        }
    }

    // Minter resource — stored at deployer, used by mint_starter.cdc
    access(all) resource Minter {

        access(FighterMinter) fun mint(
            name: String,
            combatClass: CombatClass,
            basePower: UInt64
        ): @Fighter.NFT {
            let id = Fighter.totalSupply
            Fighter.totalSupply = Fighter.totalSupply + 1
            let nft <- create NFT(
                id: id,
                name: name,
                combatClass: combatClass,
                basePower: basePower
            )
            emit Minted(id: id, name: name, combatClass: combatClass.rawValue, basePower: basePower, to: nil)
            return <- nft
        }
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
                    storagePath: Fighter.CollectionStoragePath,
                    publicPath: Fighter.CollectionPublicPath,
                    publicCollection: Type<&Fighter.Collection>(),
                    publicLinkedType: Type<&Fighter.Collection>(),
                    createEmptyCollectionFunction: fun(): @{NonFungibleToken.Collection} {
                        return <- Fighter.createEmptyCollection(nftType: Type<@Fighter.NFT>())
                    }
                )
        }
        return nil
    }

    init() {
        self.totalSupply = 0
        self.CollectionStoragePath = /storage/fighterCollection
        self.CollectionPublicPath = /public/fighterCollection
        self.MinterStoragePath = /storage/fighterMinter

        let minter <- create Minter()
        self.account.storage.save(<- minter, to: self.MinterStoragePath)

        let collection <- create Collection()
        self.account.storage.save(<- collection, to: self.CollectionStoragePath)
        let cap = self.account.capabilities.storage.issue<&Fighter.Collection>(self.CollectionStoragePath)
        self.account.capabilities.publish(cap, at: self.CollectionPublicPath)

        emit ContractInitialized()
    }
}

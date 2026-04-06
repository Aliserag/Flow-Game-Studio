/// WinnerTrophy.cdc — Soulbound(ish) NFT minted to the winner of a Prize Pool round.
///
/// Stores:
/// - roundId: which Prize Pool round was won
/// - prizeAmount: token amount (as String, representing wei) — avoids cross-VM integer width issues
/// - mintedAtBlock: Cadence block height at time of minting
///
/// Soulbound note: the trophy CAN be transferred (full NonFungibleToken compliance)
/// but the metadata is permanently immutable — it records who won what.
/// Metadata views: Display, Serial, Traits, NFTCollectionData.

import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"

access(all) contract WinnerTrophy: NonFungibleToken, ViewResolver {

    /// Entitlement held by the Minter resource.
    /// Only PrizePoolOrchestrator (which stores the Minter) can mint trophies.
    access(all) entitlement Minter

    access(all) var totalSupply: UInt64

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    /// Emitted when a trophy is minted after a round closes.
    access(all) event Minted(
        id: UInt64,
        roundId: UInt64,
        winner: Address,
        prizeAmount: String
    )

    access(all) event ContractInitialized()

    // ─────────────────────────────────────────────────────────────────────────
    // NFT Resource
    // ─────────────────────────────────────────────────────────────────────────

    /// The WinnerTrophy NFT. Immutable metadata records the win permanently.
    access(all) resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver {

        access(all) let id: UInt64

        /// The Prize Pool round ID this trophy was awarded for.
        access(all) let roundId: UInt64

        /// Prize amount in token wei as a string (avoids UInt256 cross-VM issues).
        access(all) let prizeAmount: String

        /// Cadence block height when this trophy was minted.
        access(all) let mintedAtBlock: UInt64

        /// The EVM address of the winner (hex string, 42 chars with 0x prefix).
        access(all) let evmWinnerAddress: String

        /// Emitted automatically when this resource is destroyed.
        access(all) event ResourceDestroyed(id: UInt64 = self.id, uuid: UInt64 = self.uuid)

        init(
            id: UInt64,
            roundId: UInt64,
            prizeAmount: String,
            mintedAtBlock: UInt64,
            evmWinnerAddress: String
        ) {
            self.id = id
            self.roundId = roundId
            self.prizeAmount = prizeAmount
            self.mintedAtBlock = mintedAtBlock
            self.evmWinnerAddress = evmWinnerAddress
        }

        /// MetadataViews: return supported view types.
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.NFTCollectionData>()
            ]
        }

        /// MetadataViews: resolve a view by type.
        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "Prize Pool Trophy #".concat(self.id.toString()),
                        description: "Winner of Prize Pool Round "
                            .concat(self.roundId.toString())
                            .concat(". Prize: ")
                            .concat(self.prizeAmount)
                            .concat(" wei. EVM address: ")
                            .concat(self.evmWinnerAddress),
                        thumbnail: MetadataViews.HTTPFile(
                            url: "https://prize-pool.example/trophy/".concat(self.id.toString())
                        )
                    )

                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.id)

                case Type<MetadataViews.Traits>():
                    let traits: [MetadataViews.Trait] = [
                        MetadataViews.Trait(
                            name: "roundId",
                            value: self.roundId,
                            displayType: "Number",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "prizeAmount",
                            value: self.prizeAmount,
                            displayType: "String",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "mintedAtBlock",
                            value: self.mintedAtBlock,
                            displayType: "Number",
                            rarity: nil
                        ),
                        MetadataViews.Trait(
                            name: "evmWinnerAddress",
                            value: self.evmWinnerAddress,
                            displayType: "String",
                            rarity: nil
                        )
                    ]
                    return MetadataViews.Traits(traits)

                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: WinnerTrophy.CollectionStoragePath,
                        publicPath: WinnerTrophy.CollectionPublicPath,
                        publicCollection: Type<&WinnerTrophy.Collection>(),
                        publicLinkedType: Type<&WinnerTrophy.Collection>(),
                        createEmptyCollectionFunction: fun(): @{NonFungibleToken.Collection} {
                            return <- WinnerTrophy.createEmptyCollection(nftType: Type<@WinnerTrophy.NFT>())
                        }
                    )
            }
            return nil
        }

        /// createEmptyCollection — required by NonFungibleToken.NFT interface.
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- WinnerTrophy.createEmptyCollection(nftType: Type<@WinnerTrophy.NFT>())
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Collection Resource
    // ─────────────────────────────────────────────────────────────────────────

    /// Stores WinnerTrophy NFTs for a player.
    access(all) resource Collection: NonFungibleToken.Collection {

        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init() {
            self.ownedNFTs <- {}
        }

        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let trophy <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("WinnerTrophy.Collection.withdraw: Trophy "
                    .concat(withdrawID.toString())
                    .concat(" not found"))
            return <- trophy
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let trophy <- token as! @WinnerTrophy.NFT
            self.ownedNFTs[trophy.id] <-! trophy
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

        /// Borrow a typed WinnerTrophy reference for read operations.
        access(all) view fun borrowTrophy(id: UInt64): &WinnerTrophy.NFT? {
            let ref = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}?
            return ref as! &WinnerTrophy.NFT?
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            return {Type<@WinnerTrophy.NFT>(): true}
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@WinnerTrophy.NFT>()
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- WinnerTrophy.createEmptyCollection(nftType: Type<@WinnerTrophy.NFT>())
        }

        access(all) fun forEachID(_ f: fun(UInt64): Bool) {
            self.ownedNFTs.forEachKey(f)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Minter Resource
    // ─────────────────────────────────────────────────────────────────────────

    /// Mints WinnerTrophy NFTs. Stored at deployer; used by PrizePoolOrchestrator.
    access(all) resource MinterResource {

        /// Mint a new trophy and return it. Caller is responsible for depositing.
        access(Minter) fun mint(
            roundId: UInt64,
            prizeAmount: String,
            evmWinnerAddress: String
        ): @WinnerTrophy.NFT {
            let id = WinnerTrophy.totalSupply
            WinnerTrophy.totalSupply = WinnerTrophy.totalSupply + 1

            let trophy <- create NFT(
                id: id,
                roundId: roundId,
                prizeAmount: prizeAmount,
                mintedAtBlock: getCurrentBlock().height,
                evmWinnerAddress: evmWinnerAddress
            )

            // winner address will be set by caller — event emitted after deposit
            return <- trophy
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Contract-level Functions
    // ─────────────────────────────────────────────────────────────────────────

    /// Required by NonFungibleToken interface.
    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    /// ViewResolver: return supported contract views.
    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [Type<MetadataViews.NFTCollectionData>()]
    }

    /// ViewResolver: resolve contract views.
    access(all) view fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                    storagePath: WinnerTrophy.CollectionStoragePath,
                    publicPath: WinnerTrophy.CollectionPublicPath,
                    publicCollection: Type<&WinnerTrophy.Collection>(),
                    publicLinkedType: Type<&WinnerTrophy.Collection>(),
                    createEmptyCollectionFunction: fun(): @{NonFungibleToken.Collection} {
                        return <- WinnerTrophy.createEmptyCollection(nftType: Type<@WinnerTrophy.NFT>())
                    }
                )
        }
        return nil
    }

    /// Emit a Minted event for a trophy — called after deposit so we know the owner.
    access(all) fun emitMinted(id: UInt64, roundId: UInt64, winner: Address, prizeAmount: String) {
        emit Minted(id: id, roundId: roundId, winner: winner, prizeAmount: prizeAmount)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // init
    // ─────────────────────────────────────────────────────────────────────────

    init() {
        self.totalSupply = 0
        self.CollectionStoragePath = /storage/winnerTrophyCollection
        self.CollectionPublicPath = /public/winnerTrophyCollection
        self.MinterStoragePath = /storage/winnerTrophyMinter

        // Save minter to deployer storage
        let minter <- create MinterResource()
        self.account.storage.save(<- minter, to: self.MinterStoragePath)

        // Create and publish deployer collection
        let collection <- create Collection()
        self.account.storage.save(<- collection, to: self.CollectionStoragePath)
        let cap = self.account.capabilities.storage.issue<&WinnerTrophy.Collection>(
            self.CollectionStoragePath
        )
        self.account.capabilities.publish(cap, at: self.CollectionPublicPath)

        emit ContractInitialized()
    }
}

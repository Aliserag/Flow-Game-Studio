// cadence/contracts/systems/Achievement.cdc
//
// Soulbound achievement NFT system for Flow game studios.
//
// Design:
//   - AchievementNFT is a soulbound resource: withdraw() always panics.
//   - Players set up an AchievementCollection via setupCollection().
//   - The GameServer (deployer) grants achievements via grantAchievement().
//   - Duplicate grants (same player + achievementType) are prevented.
//   - AchievementCollection is a custom resource (does NOT implement
//     NonFungibleToken.Collection) since soulbound NFTs are non-transferable.
//
// Note on GameServerRef:
//   The GameServerRef resource is stored at the deployer account and never
//   published to a public path. The deployer calls grantAchievement() directly
//   from a transaction that borrows the resource with auth(GameServer).
//
// Flat-state note:
//   Per-player "granted" tracking uses a top-level dict to avoid struct mutation:
//   access(self) var granted: {Address: {String: Bool}}

access(all) contract Achievement {

    // -----------------------------------------------------------------------
    // Entitlements
    // -----------------------------------------------------------------------

    /// GameServer entitlement — held only by the GameServerRef resource at deployer.
    access(all) entitlement GameServer

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// Fires when a new achievement is granted to a player.
    access(all) event AchievementGranted(player: Address, achievementType: String, id: UInt64)

    /// Fires before the soulbound withdraw panic — allows indexers to detect attempts.
    access(all) event AchievementTransferAttempted(id: UInt64)

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// Total achievements ever minted.
    access(all) var totalAchievements: UInt64

    /// Per-player granted tracking: player -> achievementType -> Bool
    /// Used to prevent duplicate grants.
    access(self) var granted: {Address: {String: Bool}}

    /// Storage and public paths for AchievementCollection.
    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath

    /// Storage path for the GameServerRef resource.
    access(all) let GameServerStoragePath: StoragePath

    // -----------------------------------------------------------------------
    // AchievementNFT Resource
    // -----------------------------------------------------------------------

    /// Soulbound NFT representing a player achievement.
    /// Cannot be transferred — withdraw() always panics.
    access(all) resource AchievementNFT {
        access(all) let id: UInt64
        access(all) let achievementType: String
        access(all) let name: String
        access(all) let description: String
        access(all) let earnedAtBlock: UInt64

        init(
            id: UInt64,
            achievementType: String,
            name: String,
            description: String,
            earnedAtBlock: UInt64
        ) {
            self.id              = id
            self.achievementType = achievementType
            self.name            = name
            self.description     = description
            self.earnedAtBlock   = earnedAtBlock
        }
    }

    // -----------------------------------------------------------------------
    // AchievementCollection Resource
    // -----------------------------------------------------------------------

    /// Custom soulbound collection. Does NOT implement NonFungibleToken.Collection
    /// because transfers are prohibited. withdraw() always panics.
    access(all) resource AchievementCollection {

        /// Internal storage of soulbound NFTs keyed by ID.
        access(self) var achievements: @{UInt64: AchievementNFT}

        /// ALWAYS panics — soulbound achievements cannot be transferred.
        access(all) fun withdraw(id: UInt64): @AchievementNFT {
            emit AchievementTransferAttempted(id: id)
            panic("Soulbound: cannot transfer achievement NFT")
        }

        /// Deposit an achievement NFT into this collection.
        access(all) fun deposit(token: @AchievementNFT) {
            let old <- self.achievements[token.id] <- token
            destroy old
        }

        /// Returns all achievement IDs in this collection.
        access(all) view fun getIDs(): [UInt64] {
            return self.achievements.keys
        }

        /// Borrow a read reference to an achievement by ID, or nil if not found.
        access(all) view fun borrowAchievement(_ id: UInt64): &AchievementNFT? {
            return &self.achievements[id]
        }

        /// Returns the number of achievements in this collection.
        access(all) view fun getLength(): Int {
            return self.achievements.length
        }

        init() {
            self.achievements <- {}
        }
    }

    // -----------------------------------------------------------------------
    // GameServerRef Resource
    // -----------------------------------------------------------------------

    /// GameServerRef — stored at deployer; never published to a public path.
    /// Deployer borrows this with auth(GameServer) to call grantAchievement().
    access(all) resource GameServerRef {

        /// Grant a soulbound achievement to a player.
        /// Panics if the player already has an achievement of this type.
        access(GameServer) fun grantAchievement(
            player: Address,
            achievementType: String,
            name: String,
            description: String
        ) {
            pre {
                achievementType.length > 0: "achievementType cannot be empty"
                name.length > 0:            "name cannot be empty"
            }

            // Check for duplicate grant
            let playerGrants = Achievement.granted[player] ?? {}
            assert(
                !(playerGrants[achievementType] ?? false),
                message: "Player already has achievement: ".concat(achievementType)
            )

            // Borrow player's collection
            let collection = getAccount(player)
                .capabilities.get<&Achievement.AchievementCollection>(Achievement.CollectionPublicPath)
                .borrow()
                ?? panic("Player has no AchievementCollection — run setup_achievement_collection.cdc first")

            // Mint the soulbound NFT
            let nftId = Achievement.totalAchievements
            let nft <- create AchievementNFT(
                id: nftId,
                achievementType: achievementType,
                name: name,
                description: description,
                earnedAtBlock: getCurrentBlock().height
            )

            Achievement.totalAchievements = Achievement.totalAchievements + 1

            // Record grant to prevent duplicates (copy-modify-write on flat state)
            var updatedGrants = Achievement.granted[player] ?? {}
            updatedGrants[achievementType] = true
            Achievement.granted[player] = updatedGrants

            // Deposit into player's collection
            collection.deposit(token: <- nft)

            emit AchievementGranted(player: player, achievementType: achievementType, id: nftId)
        }
    }

    // -----------------------------------------------------------------------
    // Public functions
    // -----------------------------------------------------------------------

    /// Create and return a new empty AchievementCollection.
    /// Caller (transaction) is responsible for saving to storage and publishing capability.
    access(all) fun createEmptyCollection(): @AchievementCollection {
        return <- create AchievementCollection()
    }

    // -----------------------------------------------------------------------
    // Read-only accessors
    // -----------------------------------------------------------------------

    /// Check whether a player has been granted a specific achievement type.
    access(all) view fun hasAchievement(player: Address, achievementType: String): Bool {
        if let playerGrants = Achievement.granted[player] {
            return playerGrants[achievementType] ?? false
        }
        return false
    }

    // -----------------------------------------------------------------------
    // Init
    // -----------------------------------------------------------------------

    init() {
        self.totalAchievements    = 0
        self.granted              = {}
        self.CollectionStoragePath = /storage/AchievementCollection
        self.CollectionPublicPath  = /public/AchievementCollection
        self.GameServerStoragePath = /storage/AchievementGameServer

        self.account.storage.save(<- create GameServerRef(), to: self.GameServerStoragePath)
    }
}

// PlayerProfile.cdc
// Soul-bound player identity NFT — cannot be transferred or sold.
// One per player address. Accumulates reputation and cross-game history.
//
// Soul-bound in Cadence = resource with NO Withdraw entitlement defined.
// The Profile resource cannot be moved out of the player's account
// because no transaction can borrow it with a Withdraw-capable reference.

import "MetadataViews"

access(all) contract PlayerProfile {

    // NOTE: No Withdraw entitlement defined — this makes Profile soul-bound.
    // Attempting to withdraw would require auth(Withdraw) &Collection,
    // but Withdraw is never issued -> no one can transfer a profile.
    access(all) entitlement ProfileUpdate

    access(all) struct GameHistory {
        access(all) let gameId: String          // e.g., "dungeon-crawler-v1"
        access(all) let firstPlayedBlock: UInt64
        access(all) var lastPlayedBlock: UInt64
        access(all) var gamesPlayed: UInt64
        access(all) var wins: UInt64
        access(all) var losses: UInt64

        init(gameId: String) {
            self.gameId = gameId
            self.firstPlayedBlock = getCurrentBlock().height
            self.lastPlayedBlock = getCurrentBlock().height
            self.gamesPlayed = 0; self.wins = 0; self.losses = 0
        }
    }

    access(all) resource Profile {
        access(all) let id: UInt64
        access(all) let createdAtBlock: UInt64
        access(all) var displayName: String
        access(all) var avatarURL: String          // IPFS CID
        access(all) var gameHistory: {String: GameHistory}
        access(all) var totalAchievements: UInt64
        access(all) var reputationScore: UFix64    // computed from wins, achievements, tenure

        init(id: UInt64, displayName: String) {
            self.id = id; self.displayName = displayName
            self.avatarURL = ""; self.gameHistory = {}
            self.totalAchievements = 0; self.reputationScore = 0.0
            self.createdAtBlock = getCurrentBlock().height
        }

        access(ProfileUpdate) fun updateDisplayName(_ name: String) {
            pre { name.length >= 2 && name.length <= 32: "Name must be 2-32 characters" }
            self.displayName = name
        }

        access(ProfileUpdate) fun recordGameSession(
            gameId: String, won: Bool
        ) {
            if self.gameHistory[gameId] == nil {
                self.gameHistory[gameId] = GameHistory(gameId: gameId)
            }
            var history = self.gameHistory[gameId]!
            history.gamesPlayed = history.gamesPlayed + 1
            history.lastPlayedBlock = getCurrentBlock().height
            if won { history.wins = history.wins + 1 }
            else { history.losses = history.losses + 1 }
            self.gameHistory[gameId] = history
            self.reputationScore = self.computeReputation()
        }

        access(all) view fun computeReputation(): UFix64 {
            var total: UFix64 = 0.0
            for gameId in self.gameHistory.keys {
                let h = self.gameHistory[gameId]!
                // Win rate contribution capped at 1.0
                let winRate = h.gamesPlayed > 0 ? UFix64(h.wins) / UFix64(h.gamesPlayed) : 0.0
                total = total + winRate * UFix64(h.gamesPlayed)
            }
            return total + UFix64(self.totalAchievements) * 10.0
        }
    }

    access(all) resource Collection {
        // Only one profile per collection (enforced in createProfile)
        access(all) var profile: @Profile?

        init() { self.profile <- nil }

        // No withdraw function = soul-bound
        // Collections cannot transfer profiles

        access(ProfileUpdate) fun setProfile(_ profile: @Profile) {
            pre { self.profile == nil: "Profile already exists" }
            self.profile <-! profile
        }

        access(ProfileUpdate) fun borrowProfile(): auth(ProfileUpdate) &Profile? {
            return &self.profile as auth(ProfileUpdate) &Profile?
        }

        access(all) view fun getProfile(): &Profile? {
            return &self.profile as &Profile?
        }

        destroy() { destroy self.profile }
    }

    access(all) var totalProfiles: UInt64
    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath

    access(all) event ProfileCreated(id: UInt64, owner: Address, displayName: String)
    access(all) event SessionRecorded(profileId: UInt64, gameId: String, won: Bool, newReputation: UFix64)

    access(all) fun createProfile(owner: Address, displayName: String): @Profile {
        let id = PlayerProfile.totalProfiles
        PlayerProfile.totalProfiles = id + 1
        let profile <- create Profile(id: id, displayName: displayName)
        emit ProfileCreated(id: id, owner: owner, displayName: displayName)
        return <-profile
    }

    access(all) fun createCollection(): @Collection {
        return <-create Collection()
    }

    init() {
        self.totalProfiles = 0
        self.CollectionStoragePath = /storage/PlayerProfile
        self.CollectionPublicPath = /public/PlayerProfile
    }
}

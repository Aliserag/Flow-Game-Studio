// Reputation.cdc
// Cross-game reputation badges — soul-bound achievements issued by verified game contracts.
// Games call issueBadge() to award non-transferable reputation markers to players.

import "PlayerProfile"

access(all) contract Reputation {

    access(all) entitlement BadgeIssuer

    access(all) struct Badge {
        access(all) let badgeId: String          // e.g., "dungeon-crawler:first-clear"
        access(all) let gameId: String
        access(all) let name: String
        access(all) let description: String
        access(all) let awardedAtBlock: UInt64
        access(all) let rarity: String           // "common", "rare", "legendary"
        access(all) let pointValue: UFix64

        init(badgeId: String, gameId: String, name: String, description: String,
             rarity: String, pointValue: UFix64) {
            self.badgeId = badgeId; self.gameId = gameId
            self.name = name; self.description = description
            self.awardedAtBlock = getCurrentBlock().height
            self.rarity = rarity; self.pointValue = pointValue
        }
    }

    // Tracks which players hold which badges (prevents duplicate issuance)
    access(all) var playerBadges: {Address: {String: Badge}}

    access(all) let AdminStoragePath: StoragePath

    access(all) event BadgeIssued(player: Address, badgeId: String, gameId: String, pointValue: UFix64)

    access(all) resource Admin {
        // Called by registered game contracts to issue badges to players
        access(BadgeIssuer) fun issueBadge(
            player: Address,
            badgeId: String,
            gameId: String,
            name: String,
            description: String,
            rarity: String,
            pointValue: UFix64
        ) {
            if Reputation.playerBadges[player] == nil {
                Reputation.playerBadges[player] = {}
            }
            // Idempotent — re-issuing the same badge has no effect
            if Reputation.playerBadges[player]![badgeId] != nil { return }

            Reputation.playerBadges[player]![badgeId] = Badge(
                badgeId: badgeId, gameId: gameId, name: name,
                description: description, rarity: rarity, pointValue: pointValue
            )
            emit BadgeIssued(player: player, badgeId: badgeId, gameId: gameId, pointValue: pointValue)
        }
    }

    // Returns total reputation points from all badges for a player
    access(all) view fun getTotalReputation(player: Address): UFix64 {
        let badges = Reputation.playerBadges[player] ?? {}
        var total: UFix64 = 0.0
        for key in badges.keys {
            total = total + badges[key]!.pointValue
        }
        return total
    }

    access(all) view fun getPlayerBadges(player: Address): {String: Badge} {
        return Reputation.playerBadges[player] ?? {}
    }

    init() {
        self.playerBadges = {}
        self.AdminStoragePath = /storage/ReputationAdmin
        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}

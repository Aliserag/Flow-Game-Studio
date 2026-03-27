// AchievementAttachment.cdc
// Permanent achievement record attached to an NFT. Travels with the NFT.
// Achievements are append-only — once earned, never removed.
// This creates a provenance trail: "this NFT won Tournament #42, Season 3 champion"

import "NonFungibleToken"

access(all) contract AchievementAttachment {

    access(all) entitlement GrantAchievement

    access(all) struct Achievement {
        access(all) let achievementId: String
        access(all) let name: String
        access(all) let description: String
        access(all) let earnedAtBlock: UInt64
        access(all) let earnedByAddress: Address
        access(all) let metadata: {String: String}   // arbitrary k/v for extra data

        init(achievementId: String, name: String, description: String,
             earnedBy: Address, metadata: {String: String}) {
            self.achievementId = achievementId
            self.name = name
            self.description = description
            self.earnedAtBlock = getCurrentBlock().height
            self.earnedByAddress = earnedBy
            self.metadata = metadata
        }
    }

    access(all) event AchievementGranted(nftId: UInt64, achievementId: String, earnedBy: Address)

    access(all) attachment Achievements for NonFungibleToken.NFT {

        // Ordered list — achievements appear in earn order
        access(all) var achievements: [Achievement]
        access(all) var achievementIds: {String: Bool}  // fast duplicate check

        init() {
            self.achievements = []
            self.achievementIds = {}
        }

        access(all) view fun count(): Int { return self.achievements.length }

        access(all) view fun hasAchievement(_ id: String): Bool {
            return self.achievementIds[id] == true
        }

        access(GrantAchievement) fun grant(
            achievementId: String,
            name: String,
            description: String,
            earnedBy: Address,
            metadata: {String: String}
        ) {
            pre { !self.achievementIds[achievementId] ?? false: "Achievement already granted: ".concat(achievementId) }
            let achievement = Achievement(
                achievementId: achievementId, name: name, description: description,
                earnedBy: earnedBy, metadata: metadata
            )
            self.achievements.append(achievement)
            self.achievementIds[achievementId] = true
            emit AchievementGranted(nftId: self.base.id, achievementId: achievementId, earnedBy: earnedBy)
        }
    }
}

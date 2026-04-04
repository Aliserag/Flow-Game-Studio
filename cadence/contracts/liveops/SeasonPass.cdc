import "NonFungibleToken"
import "FungibleToken"
import "Scheduler"
import "EmergencyPause"
import "GameToken"

access(all) contract SeasonPass {

    access(all) entitlement SeasonAdmin

    access(all) struct SeasonConfig {
        access(all) let seasonId: UInt64
        access(all) let name: String
        access(all) let startEpoch: UInt64
        access(all) let endEpoch: UInt64
        access(all) let maxTier: UInt8          // e.g., 100
        access(all) let xpPerTier: UFix64       // XP needed per tier
        access(all) let freeRewards: {UInt8: String}  // tier -> reward description
        access(all) let premiumRewards: {UInt8: String}

        init(seasonId: UInt64, name: String, startEpoch: UInt64, endEpoch: UInt64,
             maxTier: UInt8, xpPerTier: UFix64,
             freeRewards: {UInt8: String}, premiumRewards: {UInt8: String}) {
            self.seasonId = seasonId; self.name = name
            self.startEpoch = startEpoch; self.endEpoch = endEpoch
            self.maxTier = maxTier; self.xpPerTier = xpPerTier
            self.freeRewards = freeRewards; self.premiumRewards = premiumRewards
        }
    }

    access(all) struct PlayerProgress {
        access(all) var xp: UFix64
        access(all) var currentTier: UInt8
        access(all) var hasPremium: Bool
        access(all) var claimedTiers: [UInt8]

        access(contract) fun addXP(_ amount: UFix64) { self.xp = self.xp + amount }
        access(contract) fun setTier(_ tier: UInt8) { self.currentTier = tier }
        access(contract) fun setPremium(_ v: Bool) { self.hasPremium = v }

        init() {
            self.xp = 0.0; self.currentTier = 0
            self.hasPremium = false; self.claimedTiers = []
        }
    }

    access(all) var activeSeason: SeasonConfig?
    access(all) var playerProgress: {Address: PlayerProgress}
    access(all) let AdminStoragePath: StoragePath

    access(all) event SeasonStarted(seasonId: UInt64, name: String)
    access(all) event XPAwarded(player: Address, amount: UFix64, newTier: UInt8)
    access(all) event RewardClaimed(player: Address, tier: UInt8, isPremium: Bool)
    access(all) event PremiumPurchased(player: Address, seasonId: UInt64)

    access(all) resource Admin {
        access(SeasonAdmin) fun startSeason(config: SeasonConfig) {
            EmergencyPause.assertNotPaused()
            SeasonPass.activeSeason = config
            SeasonPass.playerProgress = {}
            emit SeasonStarted(seasonId: config.seasonId, name: config.name)
        }

        access(SeasonAdmin) fun awardXP(player: Address, amount: UFix64) {
            EmergencyPause.assertNotPaused()
            if SeasonPass.playerProgress[player] == nil {
                SeasonPass.playerProgress[player] = PlayerProgress()
            }
            var progress = SeasonPass.playerProgress[player]!
            progress.addXP(amount)

            let season = SeasonPass.activeSeason ?? panic("No active season")
            let newTier = UInt8(progress.xp / season.xpPerTier)
            if newTier > progress.currentTier && newTier <= season.maxTier {
                progress.setTier(newTier)
            }
            SeasonPass.playerProgress[player] = progress
            emit XPAwarded(player: player, amount: amount, newTier: progress.currentTier)
        }
    }

    access(all) fun purchasePremium(buyer: Address, payment: @{FungibleToken.Vault}) {
        // Premium costs 1000 GameTokens
        pre { payment.balance >= 1000.0: "Insufficient payment" }
        EmergencyPause.assertNotPaused()
        destroy payment  // Burn the tokens (adjust to treasury deposit as needed)

        if SeasonPass.playerProgress[buyer] == nil {
            SeasonPass.playerProgress[buyer] = PlayerProgress()
        }
        var progress = SeasonPass.playerProgress[buyer]!
        progress.setPremium(true)
        SeasonPass.playerProgress[buyer] = progress
        let season = SeasonPass.activeSeason ?? panic("No active season")
        emit PremiumPurchased(player: buyer, seasonId: season.seasonId)
    }

    init() {
        self.activeSeason = nil
        self.playerProgress = {}
        self.AdminStoragePath = /storage/SeasonPassAdmin
        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}

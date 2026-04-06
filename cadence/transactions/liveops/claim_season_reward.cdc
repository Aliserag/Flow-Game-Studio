import "SeasonPass"

transaction(tier: UInt8) {
    let playerAddress: Address

    prepare(signer: auth(BorrowValue) &Account) {
        self.playerAddress = signer.address
    }

    execute {
        let season = SeasonPass.activeSeason ?? panic("No active season")
        let progress = SeasonPass.playerProgress[self.playerAddress]
            ?? panic("No progress found for player")

        assert(progress.currentTier >= tier, message: "Tier not reached yet")
        assert(!progress.claimedTiers.contains(tier), message: "Tier already claimed")

        // Validate reward exists
        if progress.hasPremium {
            assert(season.premiumRewards[tier] != nil || season.freeRewards[tier] != nil,
                message: "No reward at this tier")
        } else {
            assert(season.freeRewards[tier] != nil, message: "No free reward at this tier")
        }

        // Note: Actual reward distribution (NFT mint/token transfer) handled by reward system
        log("Reward claimed at tier: ".concat(tier.toString()))
        emit SeasonPass.RewardClaimed(player: self.playerAddress, tier: tier, isPremium: progress.hasPremium)
    }
}

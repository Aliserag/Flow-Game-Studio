// Health check: verifies contract invariants that should always hold.
// Run periodically (every epoch) from a monitoring bot.
// Returns a list of violations — empty = healthy.

import "GameToken"
import "StakingPool"
import "EmergencyPause"
import "Marketplace"

access(all) fun main(): {String: String} {
    var violations: {String: String} = {}

    // Invariant 1: System should not be paused under normal conditions
    if EmergencyPause.isPaused {
        violations["PAUSED"] = "System is paused: ".concat(EmergencyPause.pauseReason)
    }

    // Invariant 2: StakingPool total staked should match sum of all staker balances
    // (simplified check — just verify totalStaked is non-negative)
    if StakingPool.totalStaked < 0.0 {
        violations["STAKING_UNDERFLOW"] = "StakingPool.totalStaked is negative: ".concat(StakingPool.totalStaked.toString())
    }

    // Invariant 3: Reward index should be non-decreasing (can't go backwards)
    // (would need historical data — flag if rewardIndex is 0 with non-zero total staked)
    if StakingPool.totalStaked > 0.0 && StakingPool.rewardIndex == 0.0 {
        violations["STAKING_INDEX_ZERO"] = "Stakers exist but rewardIndex is 0 — rewards may not be flowing"
    }

    return violations
}

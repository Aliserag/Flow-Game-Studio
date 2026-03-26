// cadence/transactions/staking/claim_yield.cdc
//
// Claim accumulated yield for a staking position.
// Yield is calculated as: amount * yieldRatePerMille * blocksElapsed / 1_000_000
// Paid from the yield pool; receiver must have a GameToken vault set up.
import "Staking"

transaction(positionId: UInt64) {

    prepare(player: auth(Storage) &Account) {
        // claimYield sends yield directly to player's receiver capability
        Staking.claimYield(
            positionId: positionId,
            player: player.address
        )
    }
}

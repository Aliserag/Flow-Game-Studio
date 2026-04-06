/// close_round.cdc — Admin transaction to close the current prize pool round.
///
/// What this transaction does atomically:
///   1. Uses RandomBeaconHistory VRF to pick a winner from the depositor list
///   2. Calls EVM PrizePool.closeRound(winner) via the COA — releases ERC-20 prize
///   3. Mints a WinnerTrophy NFT to the winner's Cadence account
///
/// Parameters:
///   - depositors: array of EVM address strings (hex, 0x-prefixed) for current round
///   - evmRoundId: UInt256 matching PrizePool.roundId() on EVM
///   - commitBlockHeight: a past sealed block used for RandomBeaconHistory VRF
///   - secret: additional entropy (use a random UInt256 generated off-chain)
///   - winnerFlowAddress: Cadence address to receive the WinnerTrophy NFT
///   - prizeAmountStr: total prize in wei as a string (for trophy metadata)
///
/// The admin must:
///   1. Have run setup_coa.cdc (COA exists at /storage/evm)
///   2. The COA must be the owner() of the EVM PrizePool
///   3. The winner must have run setup_trophy_collection.cdc
///   4. PrizePoolOrchestrator.prizePoolEVMAddress must be set

import "PrizePoolOrchestrator"

transaction(
    depositors: [String],
    evmRoundId: UInt256,
    commitBlockHeight: UInt64,
    secret: UInt256,
    winnerFlowAddress: Address,
    prizeAmountStr: String
) {
    prepare(signer: auth(BorrowValue) &Account) {
        // Delegate to PrizePoolOrchestrator which orchestrates the full cross-VM flow
        PrizePoolOrchestrator.closeRound(
            signer: signer,
            depositors: depositors,
            evmRoundId: evmRoundId,
            commitBlockHeight: commitBlockHeight,
            secret: secret,
            winnerFlowAddress: winnerFlowAddress,
            prizeAmountStr: prizeAmountStr
        )
    }

    execute {
        log("Round closed successfully")
    }
}

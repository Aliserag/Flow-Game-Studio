/// get_round_info.cdc — Returns current orchestrator state (cadence round count).
///
/// Note: EVM round state (roundId, isOpen, totalDeposited, depositors)
/// must be queried via ethers.js directly — scripts here cover the Cadence side.

import "PrizePoolOrchestrator"

access(all) struct RoundInfo {
    access(all) let cadenceRoundCount: UInt64
    access(all) let prizePoolEVMAddressSet: Bool

    init(cadenceRoundCount: UInt64, prizePoolEVMAddressSet: Bool) {
        self.cadenceRoundCount = cadenceRoundCount
        self.prizePoolEVMAddressSet = prizePoolEVMAddressSet
    }
}

access(all) fun main(): RoundInfo {
    return RoundInfo(
        cadenceRoundCount: PrizePoolOrchestrator.cadenceRoundCount,
        prizePoolEVMAddressSet: PrizePoolOrchestrator.prizePoolEVMAddress != nil
    )
}

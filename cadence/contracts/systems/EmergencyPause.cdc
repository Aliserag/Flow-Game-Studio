// EmergencyPause.cdc
// Circuit-breaker contract. Import and call assertNotPaused() at the top of
// any state-mutating function in game contracts.
//
// IMPORTANT: Pausing blocks NEW transactions only. Existing player assets
// (NFTs, tokens) remain untouched in player accounts.
import "EmergencyPause"

access(all) contract EmergencyPause {

    access(all) entitlement Pauser
    access(all) entitlement Unpauser

    access(all) var isPaused: Bool
    access(all) var pauseReason: String
    access(all) var pausedAtBlock: UInt64
    access(all) var pausedBy: Address?

    access(all) let AdminStoragePath: StoragePath

    access(all) event SystemPaused(reason: String, block: UInt64, by: Address)
    access(all) event SystemUnpaused(block: UInt64, by: Address)

    access(all) resource Admin {
        access(Pauser) fun pause(reason: String, by: Address) {
            EmergencyPause.isPaused = true
            EmergencyPause.pauseReason = reason
            EmergencyPause.pausedAtBlock = getCurrentBlock().height
            EmergencyPause.pausedBy = by
            emit SystemPaused(reason: reason, block: getCurrentBlock().height, by: by)
        }

        access(Unpauser) fun unpause(by: Address) {
            EmergencyPause.isPaused = false
            EmergencyPause.pauseReason = ""
            EmergencyPause.pausedBy = nil
            emit SystemUnpaused(block: getCurrentBlock().height, by: by)
        }
    }

    // Call this at the start of any state-mutating game function
    access(all) fun assertNotPaused() {
        assert(!EmergencyPause.isPaused,
            message: "System paused: ".concat(EmergencyPause.pauseReason))
    }

    init() {
        self.isPaused = false
        self.pauseReason = ""
        self.pausedAtBlock = 0
        self.pausedBy = nil
        self.AdminStoragePath = /storage/EmergencyPauseAdmin

        let admin <- create Admin()
        self.account.storage.save(<-admin, to: self.AdminStoragePath)
    }
}

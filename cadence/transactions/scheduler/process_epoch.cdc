// cadence/transactions/scheduler/process_epoch.cdc
import "Scheduler"

transaction {
    execute {
        let processed = Scheduler.processEpoch()
        log("Epoch advanced. Actions processed: ".concat(processed.toString()))
    }
}

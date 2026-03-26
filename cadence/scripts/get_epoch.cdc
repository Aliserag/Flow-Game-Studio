// cadence/scripts/get_epoch.cdc
import "Scheduler"

access(all) fun main(): {String: AnyStruct} {
    return {
        "currentEpoch": Scheduler.currentEpoch,
        "epochBlockLength": Scheduler.epochBlockLength,
        "blocksUntilNext": Scheduler.blocksUntilNextEpoch(),
        "currentBlock": getCurrentBlock().height
    }
}

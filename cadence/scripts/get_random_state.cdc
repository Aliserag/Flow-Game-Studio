// cadence/scripts/get_random_state.cdc
import "RandomVRF"

access(all) fun main(): {String: AnyStruct} {
    return {
        "totalCommits": RandomVRF.totalCommits,
        "currentBlock": getCurrentBlock().height
    }
}

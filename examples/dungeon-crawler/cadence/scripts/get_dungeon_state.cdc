import "DungeonCrawler"

access(all) fun main(runId: UInt64): {String: AnyStruct}? {
    if let run = DungeonCrawler.runs[runId] {
        return {
            "runId": run.runId,
            "player": run.player,
            "dungeonLevel": run.dungeonLevel,
            "entryBlock": run.entryBlock,
            "result": run.result.rawValue,
            "rewardMinted": run.rewardMinted
        }
    }
    return nil
}

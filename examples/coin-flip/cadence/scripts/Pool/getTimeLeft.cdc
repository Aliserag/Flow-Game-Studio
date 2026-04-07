import "CoinFlip"

access(all) fun main(id: UInt64): Int {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    let poolRef = CoinFlip.borrowPool(id: id)
    let diff = Int(poolRef.endTime) - Int(getCurrentBlock().timestamp)
    return diff > 0 ? diff : 0
}

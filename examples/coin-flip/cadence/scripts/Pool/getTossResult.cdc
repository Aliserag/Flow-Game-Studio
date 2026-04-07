import "CoinFlip"

access(all) fun main(id: UInt64): String {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).tossResult
}

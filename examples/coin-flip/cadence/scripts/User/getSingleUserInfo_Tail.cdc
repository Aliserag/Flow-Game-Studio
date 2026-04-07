import CoinFlip from 0xCoinFlip

access(all) fun main(id: UInt64, addr: Address): &CoinFlip.TailBet_User {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).getTailBetUserInfo(_addr: addr)
}

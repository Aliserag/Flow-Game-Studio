/// get_flip.cdc — Return a single Commit for (player, flipId), or nil.
import CoinFlip from "CoinFlip"

access(all) fun main(player: Address, flipId: UInt64): CoinFlip.Commit? {
    return CoinFlip.getFlip(player: player, flipId: flipId)
}

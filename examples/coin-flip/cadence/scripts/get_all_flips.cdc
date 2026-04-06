/// get_all_flips.cdc — Return all Commits for a player, keyed by flip ID.
import CoinFlip from "CoinFlip"

access(all) fun main(player: Address): {UInt64: CoinFlip.Commit} {
    return CoinFlip.getFlipsForPlayer(player: player)
}

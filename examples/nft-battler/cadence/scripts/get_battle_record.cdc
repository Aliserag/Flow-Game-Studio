// get_battle_record.cdc — Return the W/L record for a specific Fighter NFT.
// Returns a dictionary for broad compatibility with the Cadence testing framework.

import Fighter from "Fighter"

access(all) fun main(account: Address, fighterId: UInt64): {String: AnyStruct}? {
    let collection = getAccount(account)
        .capabilities.get<&Fighter.Collection>(Fighter.CollectionPublicPath)
        .borrow()
        ?? panic("get_battle_record: Account "
            .concat(account.toString())
            .concat(" has no Fighter collection"))

    let fighter = collection.borrowFighterNFT(id: fighterId)
    if fighter == nil {
        return nil
    }
    let f = fighter!

    let wins = f.wins
    let losses = f.losses
    let total = wins + losses
    var winRate: UFix64 = 0.0
    if total > 0 {
        winRate = UFix64(wins) / UFix64(total)
    }

    return {
        "fighterId": f.id,
        "fighterName": f.name,
        "wins": wins,
        "losses": losses,
        "totalBattles": total,
        "winRate": winRate
    }
}

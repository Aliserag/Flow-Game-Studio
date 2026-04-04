// get_fighters.cdc — Return all Fighter NFTs owned by an account.
// Returns an array of FighterInfo structs including effective power and W/L records.

import Fighter from "Fighter"
import PowerUp from "PowerUp"

access(all) struct FighterInfo {
    access(all) let id: UInt64
    access(all) let name: String
    access(all) let combatClass: String
    access(all) let basePower: UInt64
    access(all) let effectivePower: UInt64
    access(all) let wins: UInt64
    access(all) let losses: UInt64
    access(all) let hasPowerUp: Bool
    access(all) let powerUpName: String?
    access(all) let powerUpBonus: UInt64?

    init(
        id: UInt64,
        name: String,
        combatClass: String,
        basePower: UInt64,
        effectivePower: UInt64,
        wins: UInt64,
        losses: UInt64,
        hasPowerUp: Bool,
        powerUpName: String?,
        powerUpBonus: UInt64?
    ) {
        self.id = id
        self.name = name
        self.combatClass = combatClass
        self.basePower = basePower
        self.effectivePower = effectivePower
        self.wins = wins
        self.losses = losses
        self.hasPowerUp = hasPowerUp
        self.powerUpName = powerUpName
        self.powerUpBonus = powerUpBonus
    }
}

access(all) fun main(account: Address): [FighterInfo] {
    let collection = getAccount(account)
        .capabilities.get<&Fighter.Collection>(Fighter.CollectionPublicPath)
        .borrow()
        ?? panic("get_fighters: Account "
            .concat(account.toString())
            .concat(" has no Fighter collection"))

    let ids = collection.getIDs()
    var results: [FighterInfo] = []

    for id in ids {
        if let fighter = collection.borrowFighterNFT(id: id) {
            var hasPowerUp = false
            var powerUpName: String? = nil
            var powerUpBonus: UInt64? = nil

            if let boost = fighter[PowerUp.Boost] {
                hasPowerUp = true
                powerUpName = boost.name
                powerUpBonus = boost.bonusPower
            }

            results.append(FighterInfo(
                id: fighter.id,
                name: fighter.name,
                combatClass: fighter.combatClassName(),
                basePower: fighter.basePower,
                effectivePower: fighter.effectivePower(),
                wins: fighter.wins,
                losses: fighter.losses,
                hasPowerUp: hasPowerUp,
                powerUpName: powerUpName,
                powerUpBonus: powerUpBonus
            ))
        }
    }

    return results
}

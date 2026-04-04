// get_fighter.cdc — Return detailed info about a single Fighter NFT.
// Returns a struct with all stats including effective power and PowerUp bonus.

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

access(all) fun main(account: Address, fighterId: UInt64): FighterInfo? {
    let collection = getAccount(account)
        .capabilities.get<&Fighter.Collection>(Fighter.CollectionPublicPath)
        .borrow()
        ?? panic("get_fighter: Account "
            .concat(account.toString())
            .concat(" has no Fighter collection"))

    let fighter = collection.borrowFighterNFT(id: fighterId)
    if fighter == nil {
        return nil
    }
    let f = fighter!

    var hasPowerUp = false
    var powerUpName: String? = nil
    var powerUpBonus: UInt64? = nil

    if let boost = f[PowerUp.Boost] {
        hasPowerUp = true
        powerUpName = boost.name
        powerUpBonus = boost.bonusPower
    }

    return FighterInfo(
        id: f.id,
        name: f.name,
        combatClass: f.combatClassName(),
        basePower: f.basePower,
        effectivePower: f.effectivePower(),
        wins: f.wins,
        losses: f.losses,
        hasPowerUp: hasPowerUp,
        powerUpName: powerUpName,
        powerUpBonus: powerUpBonus
    )
}

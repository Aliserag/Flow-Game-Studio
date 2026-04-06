// mint_powerup.cdc — Mint a PowerUp NFT to a player's collection.
// Called by the app/admin account (the account that holds the PowerUp Minter resource).
// The recipient must have already called setup_account.cdc.
//
// powerUpType: 0=Sword (Attack), 1=Shield (Defense), 2=Spellbook (Magic), 3=Gem (all)
// bonusPower: flat bonus added to Fighter.effectivePower() when attached

import PowerUp from "PowerUp"

transaction(recipient: Address, name: String, powerUpType: UInt8, bonusPower: UInt64) {

    let minter: auth(PowerUp.PowerUpMinter) &PowerUp.Minter

    prepare(signer: auth(Storage) &Account) {
        self.minter = signer.storage.borrow<auth(PowerUp.PowerUpMinter) &PowerUp.Minter>(
            from: PowerUp.MinterStoragePath
        ) ?? panic("mint_powerup: No PowerUp Minter found. Only the deployer can mint power-ups.")
    }

    execute {
        let collection = getAccount(recipient)
            .capabilities.get<&PowerUp.Collection>(PowerUp.CollectionPublicPath)
            .borrow()
            ?? panic("mint_powerup: Recipient "
                .concat(recipient.toString())
                .concat(" has no PowerUp collection. Call setup_account.cdc first."))

        let typeEnum = PowerUp.PowerUpType(rawValue: powerUpType)
            ?? panic("mint_powerup: Invalid powerUpType "
                .concat(powerUpType.toString())
                .concat(". Valid: 0=Sword, 1=Shield, 2=Spellbook, 3=Gem"))

        let nft <- self.minter.mint(
            name: name,
            powerUpType: typeEnum,
            bonusPower: bonusPower
        )
        collection.deposit(token: <- nft)
    }
}

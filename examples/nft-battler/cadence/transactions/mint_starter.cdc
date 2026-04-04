// mint_starter.cdc — Mint a free starter Fighter NFT to a new player's collection.
// Called by the app/admin account (the account that holds the Minter resource).
// The recipient must have already called setup_account.cdc.
//
// combatClass: 0=Attack, 1=Defense, 2=Magic
// basePower: 1–100

import Fighter from "Fighter"

transaction(recipient: Address, name: String, combatClass: UInt8, basePower: UInt64) {

    let minter: auth(Fighter.FighterMinter) &Fighter.Minter

    prepare(signer: auth(Storage) &Account) {
        self.minter = signer.storage.borrow<auth(Fighter.FighterMinter) &Fighter.Minter>(
            from: Fighter.MinterStoragePath
        ) ?? panic("mint_starter: No Fighter Minter found. Only the deployer can mint fighters.")
    }

    execute {
        let collection = getAccount(recipient)
            .capabilities.get<&Fighter.Collection>(Fighter.CollectionPublicPath)
            .borrow()
            ?? panic("mint_starter: Recipient "
                .concat(recipient.toString())
                .concat(" has no Fighter collection. Call setup_account.cdc first."))

        let classEnum = Fighter.CombatClass(rawValue: combatClass)
            ?? panic("mint_starter: Invalid combatClass "
                .concat(combatClass.toString())
                .concat(". Valid: 0=Attack, 1=Defense, 2=Magic"))

        let nft <- self.minter.mint(
            name: name,
            combatClass: classEnum,
            basePower: basePower
        )
        collection.deposit(token: <- nft)
    }
}

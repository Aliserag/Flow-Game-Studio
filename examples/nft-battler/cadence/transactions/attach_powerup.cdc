// attach_powerup.cdc — Consume a PowerUp NFT and attach its Boost to a Fighter NFT.
//
// Cadence attachment rule: attachments can ONLY be created inside an `attach` expression.
// We cannot call `create PowerUp.Boost(...)` outside of `attach ... to ...`.
//
// Steps:
// 1. Borrow the PowerUp.NFT to read its data (id, type, bonusPower, name)
// 2. Withdraw the Fighter NFT from the collection
// 3. Attach `PowerUp.Boost(...)` directly to the Fighter using `attach ... to`
// 4. Re-deposit the now-boosted Fighter
// 5. Withdraw and destroy the PowerUp NFT shell (its data now lives in the attachment)
//
// After this transaction, fighter.effectivePower() includes the bonus.
// The PowerUp NFT is permanently consumed.

import NonFungibleToken from "NonFungibleToken"
import Fighter from "Fighter"
import PowerUp from "PowerUp"

transaction(fighterId: UInt64, powerUpId: UInt64) {

    prepare(signer: auth(Storage) &Account) {
        // Borrow Fighter collection with Withdraw access to move NFTs
        let fighterCollection = signer.storage.borrow<
            auth(NonFungibleToken.Withdraw) &Fighter.Collection
        >(from: Fighter.CollectionStoragePath)
            ?? panic("attach_powerup: No Fighter collection. Call setup_account.cdc first.")

        // Borrow PowerUp collection with Withdraw access
        let powerUpCollection = signer.storage.borrow<
            auth(NonFungibleToken.Withdraw) &PowerUp.Collection
        >(from: PowerUp.CollectionStoragePath)
            ?? panic("attach_powerup: No PowerUp collection. Call setup_account.cdc first.")

        // Read the PowerUp data before withdrawing (so we can pass it to the attachment)
        let powerUpRef = powerUpCollection.borrowPowerUpNFT(id: powerUpId)
            ?? panic("attach_powerup: PowerUp NFT "
                .concat(powerUpId.toString())
                .concat(" not found"))
        let puId = powerUpRef.id
        let puType = powerUpRef.powerUpType
        let puBonus = powerUpRef.bonusPower
        let puName = powerUpRef.name

        // Withdraw the Fighter NFT
        let fighter <- fighterCollection.withdraw(withdrawID: fighterId) as! @Fighter.NFT

        // Attach the Boost directly — this is the only valid way to create an attachment
        // `attach PowerUp.Boost(...) to fighter` creates the attachment in-place
        let boostedFighter <- attach PowerUp.Boost(
            powerUpId: puId,
            powerUpType: puType,
            bonusPower: puBonus,
            name: puName
        ) to <- fighter

        // Re-deposit the boosted Fighter
        fighterCollection.deposit(token: <- boostedFighter)

        // Withdraw and destroy the PowerUp NFT shell
        // Its data is now encoded in the Boost attachment on the Fighter
        let consumed <- powerUpCollection.withdraw(withdrawID: powerUpId) as! @PowerUp.NFT
        PowerUp.emitConsumed(powerUpId: consumed.id, powerUpName: consumed.name)
        destroy consumed
    }
}

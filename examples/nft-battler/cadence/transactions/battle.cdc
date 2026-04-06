// battle.cdc — Battle two Fighter NFTs owned by the same account.
//
// Borrows the collection with NonFungibleToken.Update entitlement, then calls
// borrowFighterForBattle() to get auth(NonFungibleToken.Update) refs to each Fighter.
// BattleArena.battle() uses those refs to call recordResult() on both NFTs.
//
// Both fighters must be in the signer's collection for this demo.
// In a production multi-player setup with HybridCustody, the opponent's fighter
// would be in their app-managed account, accessible via delegated capabilities.

import NonFungibleToken from "NonFungibleToken"
import Fighter from "Fighter"
import BattleArena from "BattleArena"

transaction(myFighterId: UInt64, opponentFighterId: UInt64) {

    prepare(signer: auth(Storage) &Account) {
        // Borrow the collection with Update entitlement to enable recordResult() calls
        let collection = signer.storage.borrow<
            auth(NonFungibleToken.Update) &Fighter.Collection
        >(from: Fighter.CollectionStoragePath)
            ?? panic("battle: No Fighter collection. Call setup_account.cdc first.")

        // Get Update-entitled refs for both fighters
        let myFighter = collection.borrowFighterForBattle(id: myFighterId)
            ?? panic("battle: Fighter "
                .concat(myFighterId.toString())
                .concat(" not found"))

        let opponentFighter = collection.borrowFighterForBattle(id: opponentFighterId)
            ?? panic("battle: Opponent fighter "
                .concat(opponentFighterId.toString())
                .concat(" not found"))

        // Execute the battle — updates wins/losses on both NFTs on-chain
        let result = BattleArena.battle(
            challenger: myFighter,
            opponent: opponentFighter
        )

        if result.challengerWon {
            log("Victory! Fighter #"
                .concat(result.challengerId.toString())
                .concat(" (power: ")
                .concat(result.challengerPower.toString())
                .concat(") defeated Fighter #")
                .concat(result.opponentId.toString())
                .concat(" (power: ")
                .concat(result.opponentPower.toString())
                .concat(")"))
        } else {
            log("Defeat! Fighter #"
                .concat(result.challengerId.toString())
                .concat(" (power: ")
                .concat(result.challengerPower.toString())
                .concat(") lost to Fighter #")
                .concat(result.opponentId.toString())
                .concat(" (power: ")
                .concat(result.opponentPower.toString())
                .concat(")"))
        }
    }
}

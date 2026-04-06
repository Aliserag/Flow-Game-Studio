// BattleArena.cdc — Resolves battles between two Fighter NFTs.
//
// RPS rules:
//   Attack (0) beats Defense (1)
//   Defense (1) beats Magic (2)
//   Magic (2) beats Attack (0)
//   Same class → higher effectivePower wins; exact tie → challenger wins
//
// Both fighter references must carry NonFungibleToken.Update entitlement so that
// Fighter.NFT.recordResult() (which is access(NonFungibleToken.Update)) can be called.
// The battle.cdc transaction borrows the collection with Update entitlement and
// then calls borrowFighterForBattle() to obtain the entitled refs.
//
// RPS formula: (challengerClass + 1) % 3 == opponentClass → challenger wins
//   Attack=0:  (0+1)%3=1 → beats Defense(1)  ✓
//   Defense=1: (1+1)%3=2 → beats Magic(2)    ✓
//   Magic=2:   (2+1)%3=0 → beats Attack(0)   ✓

import NonFungibleToken from "NonFungibleToken"
import Fighter from "Fighter"

access(all) contract BattleArena {

    // Emitted when a battle concludes
    access(all) event BattleResolved(
        challengerId: UInt64,
        opponentId: UInt64,
        challengerWon: Bool,
        challengerPower: UInt64,
        opponentPower: UInt64,
        blockHeight: UInt64
    )

    // BattleResult — returned by battle() and emitted as an event
    access(all) struct BattleResult {
        access(all) let challengerId: UInt64
        access(all) let opponentId: UInt64
        access(all) let challengerWon: Bool
        access(all) let challengerPower: UInt64
        access(all) let opponentPower: UInt64
        access(all) let blockHeight: UInt64

        init(
            challengerId: UInt64,
            opponentId: UInt64,
            challengerWon: Bool,
            challengerPower: UInt64,
            opponentPower: UInt64,
            blockHeight: UInt64
        ) {
            self.challengerId = challengerId
            self.opponentId = opponentId
            self.challengerWon = challengerWon
            self.challengerPower = challengerPower
            self.opponentPower = opponentPower
            self.blockHeight = blockHeight
        }
    }

    // battle() — determine winner by RPS class, then power tiebreak.
    //
    // Requires auth(NonFungibleToken.Update) refs so recordResult() can update
    // wins/losses on the NFT. The caller obtains these via
    // collection.borrowFighterForBattle() which requires the Update entitlement
    // on the collection borrow.
    access(all) fun battle(
        challenger: auth(NonFungibleToken.Update) &Fighter.NFT,
        opponent: auth(NonFungibleToken.Update) &Fighter.NFT
    ): BattleResult {
        let cClass = challenger.combatClass.rawValue
        let oClass = opponent.combatClass.rawValue
        let challengerPower = challenger.effectivePower()
        let opponentPower = opponent.effectivePower()

        // RPS: (cClass + 1) % 3 == oClass → challenger beats opponent
        // Same class: higher effectivePower wins; tie goes to challenger
        let challengerWins: Bool =
            cClass == oClass
                ? challengerPower >= opponentPower
                : (cClass + 1) % 3 == oClass

        // Record results on both NFTs (requires NonFungibleToken.Update entitlement)
        challenger.recordResult(won: challengerWins, opponentId: opponent.id)
        opponent.recordResult(won: !challengerWins, opponentId: challenger.id)

        let result = BattleResult(
            challengerId: challenger.id,
            opponentId: opponent.id,
            challengerWon: challengerWins,
            challengerPower: challengerPower,
            opponentPower: opponentPower,
            blockHeight: getCurrentBlock().height
        )

        emit BattleResolved(
            challengerId: result.challengerId,
            opponentId: result.opponentId,
            challengerWon: result.challengerWon,
            challengerPower: result.challengerPower,
            opponentPower: result.opponentPower,
            blockHeight: result.blockHeight
        )

        return result
    }
}

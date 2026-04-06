// dispute_channel.cdc
// Files a dispute against a close submission by providing a newer state.
// Must be called within the 250-block dispute window.

import "FungibleToken"
import "GameToken"
import "StateChannel"

transaction(
    channelId: UInt64,
    newerSeqNum: UInt64,
    balanceA: UFix64,
    balanceB: UFix64,
    stateHash: [UInt8]
) {
    prepare(disputer: auth(Storage) &Account) {
        StateChannel.dispute(
            channelId: channelId,
            newerSeqNum: newerSeqNum,
            balanceA: balanceA,
            balanceB: balanceB,
            stateHash: stateHash,
            disputer: disputer.address
        )

        // After dispute is filed, immediately try to settle
        // (settlement uses the disputed state as the final state)
        let receiverA = getAccount(StateChannel.channels[channelId]!.playerA)
            .capabilities.borrow<&{FungibleToken.Receiver}>(GameToken.ReceiverPublicPath)
            ?? panic("No receiver for playerA")
        let receiverB = getAccount(StateChannel.channels[channelId]!.playerB)
            .capabilities.borrow<&{FungibleToken.Receiver}>(GameToken.ReceiverPublicPath)
            ?? panic("No receiver for playerB")

        StateChannel.settle(
            channelId: channelId,
            receiverA: receiverA,
            receiverB: receiverB
        )

        log("Dispute filed and settled for channel ".concat(channelId.toString()))
    }
}

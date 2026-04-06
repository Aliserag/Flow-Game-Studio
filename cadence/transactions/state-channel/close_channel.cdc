// close_channel.cdc
// Initiates cooperative close of a state channel.
// Submits the latest mutually-signed state. Starts the 250-block dispute window.

import "StateChannel"

transaction(
    channelId: UInt64,
    seqNum: UInt64,
    balanceA: UFix64,
    balanceB: UFix64,
    stateHash: [UInt8]
) {
    prepare(signer: auth(Storage) &Account) {
        StateChannel.initiateClose(
            channelId: channelId,
            seqNum: seqNum,
            balanceA: balanceA,
            balanceB: balanceB,
            stateHash: stateHash,
            initiator: signer.address
        )
        log("Close initiated for channel ".concat(channelId.toString()))
    }
}

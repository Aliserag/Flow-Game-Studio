/// get_trophies.cdc — Query the WinnerTrophy collection for a Flow account.
///
/// Returns an array of trophy metadata structs for display in the UI.

import "WinnerTrophy"

access(all) struct TrophyData {
    access(all) let id: UInt64
    access(all) let roundId: UInt64
    access(all) let prizeAmount: String
    access(all) let mintedAtBlock: UInt64
    access(all) let evmWinnerAddress: String

    init(
        id: UInt64,
        roundId: UInt64,
        prizeAmount: String,
        mintedAtBlock: UInt64,
        evmWinnerAddress: String
    ) {
        self.id = id
        self.roundId = roundId
        self.prizeAmount = prizeAmount
        self.mintedAtBlock = mintedAtBlock
        self.evmWinnerAddress = evmWinnerAddress
    }
}

access(all) fun main(flowAddress: Address): [TrophyData] {
    let acct = getAccount(flowAddress)
    let collection = acct.capabilities
        .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)
        .borrow()

    if collection == nil {
        // No collection set up — return empty array
        return []
    }

    let col = collection!
    let ids = col.getIDs()
    var trophies: [TrophyData] = []

    for id in ids {
        if let trophy = col.borrowTrophy(id: id) {
            trophies.append(TrophyData(
                id: trophy.id,
                roundId: trophy.roundId,
                prizeAmount: trophy.prizeAmount,
                mintedAtBlock: trophy.mintedAtBlock,
                evmWinnerAddress: trophy.evmWinnerAddress
            ))
        }
    }

    return trophies
}

// cadence/transactions/tournament/create_tournament.cdc
//
// Create a new tournament. Anyone can call this.
// Arguments:
//   name          — display name of the tournament
//   maxPlayers    — maximum number of entrants
//   entryFee      — entry fee in GameToken per player
//   durationEpochs — how many Scheduler epochs the tournament runs before resolve
import "Tournament"

transaction(name: String, maxPlayers: UInt32, entryFee: UFix64, durationEpochs: UInt64) {

    prepare(signer: auth(Storage) &Account) {
        // No storage required — Tournament contract holds all state.
    }

    execute {
        Tournament.createTournament(
            name: name,
            maxPlayers: maxPlayers,
            entryFee: entryFee,
            durationEpochs: durationEpochs
        )
    }
}

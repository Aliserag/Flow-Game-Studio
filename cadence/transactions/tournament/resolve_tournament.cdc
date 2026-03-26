// cadence/transactions/tournament/resolve_tournament.cdc
//
// Resolve a tournament after its duration has elapsed.
// Reveals the VRF committed during `start`, distributes prizes, and
// sets the tournament status to Resolved.
//
// Arguments:
//   tournamentId  — ID of the tournament to resolve
//   rankedPlayers — ordered list of player addresses, 1st place first
//   vrfSecret     — the same secret passed to start_tournament.cdc
import "Tournament"

transaction(tournamentId: UInt64, rankedPlayers: [Address], vrfSecret: UInt256) {

    prepare(signer: auth(Storage) &Account) {
        // No storage access needed — Tournament contract holds all state.
    }

    execute {
        Tournament.resolve(
            tournamentId: tournamentId,
            rankedPlayers: rankedPlayers,
            vrfSecret: vrfSecret
        )
    }
}

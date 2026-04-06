// cadence/transactions/tournament/start_tournament.cdc
//
// Start a tournament: commits a VRF secret for bracket seeding and
// transitions the tournament from Registration to Active.
//
// Arguments:
//   tournamentId — ID of the tournament to start
//   vrfSecret    — secret that will be committed now and revealed during resolve
import "Tournament"

transaction(tournamentId: UInt64, vrfSecret: UInt256) {

    prepare(signer: auth(Storage) &Account) {
        // No storage access needed — Tournament contract holds all state.
    }

    execute {
        Tournament.start(tournamentId: tournamentId, vrfSecret: vrfSecret)
    }
}

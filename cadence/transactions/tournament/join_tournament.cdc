// cadence/transactions/tournament/join_tournament.cdc
//
// Join a tournament by paying the entry fee from the signer's GameToken vault.
// The entry fee is withdrawn and escrowed in the Tournament contract until resolution.
import "FungibleToken"
import "GameToken"
import "Tournament"

transaction(tournamentId: UInt64) {

    prepare(player: auth(Storage) &Account) {
        // Look up the required entry fee
        let tournament = Tournament.getTournament(tournamentId)
            ?? panic("Tournament not found: ".concat(tournamentId.toString()))

        // Borrow the player's GameToken vault with Withdraw entitlement
        let vault = player.storage.borrow<auth(FungibleToken.Withdraw) &GameToken.Vault>(
            from: GameToken.VaultStoragePath
        ) ?? panic("No GameToken vault found — run setup_token_vault.cdc first")

        // Withdraw the exact entry fee and pass it to the contract
        let payment <- vault.withdraw(amount: tournament.entryFee)
        Tournament.join(
            tournamentId: tournamentId,
            player: player.address,
            entryPayment: <- payment
        )
    }
}

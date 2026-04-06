/// setup_account.cdc — No-op account setup for coin flip.
///
/// Coin flip requires no collection or vault initialization.
/// This transaction exists as a placeholder so the sponsor service
/// can cover account setup costs in a walletless-onboarding flow.
transaction {
    prepare(signer: &Account) {
        // Account exists — nothing to initialize for coin flip.
        log("Account ready: ".concat(signer.address.toString()))
    }
}

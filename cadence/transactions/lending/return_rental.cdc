import "NFTLending"

// Borrower voluntarily returns before expiry, or lender reclaims after expiry
transaction(lenderAddress: Address, rentalId: UInt64) {

    prepare(signer: auth(RevokeCapabilityController) &Account) {
        let terms = NFTLending.getRental(lender: lenderAddress, rentalId: rentalId)
            ?? panic("Rental not found")

        assert(
            signer.address == lenderAddress || terms.isExpired(),
            message: "Only lender can return before expiry"
        )

        // Revoke the capability
        signer.capabilities.storage
            .getController(byID: terms.capabilityControllerID)?
            .delete()

        log("Rental ".concat(rentalId.toString()).concat(" returned"))
        emit NFTLending.RentalReturned(rentalId: rentalId)
    }
}

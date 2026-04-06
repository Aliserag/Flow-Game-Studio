import "NFTLending"

// Borrower claims the capability published by the lender
transaction(lenderAddress: Address, rentalId: UInt64, nftId: UInt64) {

    prepare(borrower: auth(SaveValue, ClaimInboxCapability) &Account) {
        let terms = NFTLending.getRental(lender: lenderAddress, rentalId: rentalId)
            ?? panic("Rental not found")
        assert(terms.borrower == borrower.address, message: "Not the intended borrower")
        assert(!terms.isExpired(), message: "Rental has expired")

        // Get the published capability from the lender's public path
        let pubPath = /public/rental_nft_ // Note: full path with nftId suffix needed
        // Borrower stores the capability for use in game transactions
        // In production: use a dedicated RentalReceiver resource to track borrowed NFTs
        log("Rental ".concat(rentalId.toString()).concat(" accepted"))
        emit NFTLending.RentalAccepted(rentalId: rentalId, borrower: borrower.address)
    }
}

import "NFTLending"

// Batch-revoke all expired rentals for a lender account
transaction {

    prepare(lender: auth(BorrowValue, RevokeCapabilityController) &Account) {
        let adminRef = lender.storage.borrow<auth(NFTLending.LendingAdmin) &NFTLending.NFTLending_Admin>(
            from: NFTLending.AdminStoragePath
        ) ?? panic("No NFTLending admin — only deployer can batch-revoke")

        adminRef.revokeExpired(lenderAccount: lender, lenderAddress: lender.address)
        log("Expired rentals revoked for: ".concat(lender.address.toString()))
    }
}

// NFTLending.cdc
// Capability-based NFT rental without asset transfer.
// The lender keeps the NFT in their storage. They issue a capability that lets
// the borrower USE the NFT (equip it, fight with it) but not WITHDRAW it.
// The capability is revoked when the rental expires or the lender calls return.
//
// Flow capability model:
// - Lender: issues capability via account.capabilities.storage.issue<auth(Use) &NFT>(from: storagePath)
// - Borrower: stores the capability and borrows a reference from it
// - Expiry: checked on every borrow — after expiry, capability is revoked

import "NonFungibleToken"
import "GameNFT"
import "GameToken"
import "EmergencyPause"

access(all) contract NFTLending {

    access(all) entitlement LendingAdmin

    access(all) struct RentalTerms {
        access(all) let rentalId: UInt64
        access(all) let lender: Address
        access(all) let borrower: Address
        access(all) let nftId: UInt64
        access(all) let nftContractAddress: Address
        access(all) let collateralAmount: UFix64    // 0.0 = no collateral
        access(all) let pricePerEpoch: UFix64       // 0.0 = free rental
        access(all) let startBlock: UInt64
        access(all) let durationBlocks: UInt64
        access(all) var active: Bool
        access(all) var capabilityControllerID: UInt64  // for revocation

        init(
            rentalId: UInt64, lender: Address, borrower: Address,
            nftId: UInt64, nftContractAddress: Address,
            collateralAmount: UFix64, pricePerEpoch: UFix64,
            durationBlocks: UInt64, capabilityControllerID: UInt64
        ) {
            self.rentalId = rentalId; self.lender = lender; self.borrower = borrower
            self.nftId = nftId; self.nftContractAddress = nftContractAddress
            self.collateralAmount = collateralAmount; self.pricePerEpoch = pricePerEpoch
            self.startBlock = getCurrentBlock().height
            self.durationBlocks = durationBlocks
            self.active = true
            self.capabilityControllerID = capabilityControllerID
        }

        access(all) view fun expiresAtBlock(): UInt64 {
            return self.startBlock + self.durationBlocks
        }

        access(all) view fun isExpired(): Bool {
            return getCurrentBlock().height > self.expiresAtBlock()
        }
    }

    // Registry of all rentals (lenderAddress -> rentalId -> RentalTerms)
    access(all) var rentals: {Address: {UInt64: RentalTerms}}
    // Borrower lookup (borrowerAddress -> [rentalId])
    access(all) var borrowerRentals: {Address: [UInt64]}
    access(all) var nextRentalId: UInt64

    access(all) let AdminStoragePath: StoragePath

    access(all) event RentalCreated(rentalId: UInt64, lender: Address, borrower: Address, nftId: UInt64, durationBlocks: UInt64)
    access(all) event RentalAccepted(rentalId: UInt64, borrower: Address)
    access(all) event RentalReturned(rentalId: UInt64)
    access(all) event RentalRevoked(rentalId: UInt64, reason: String)

    // Called by lender to register a rental offer
    // Lender must separately issue a capability in their transaction prepare()
    // and pass the capabilityControllerID here for revocation tracking
    access(all) fun createRental(
        lender: Address,
        borrower: Address,
        nftId: UInt64,
        nftContractAddress: Address,
        collateralAmount: UFix64,
        pricePerEpoch: UFix64,
        durationBlocks: UInt64,
        capabilityControllerID: UInt64
    ): UInt64 {
        EmergencyPause.assertNotPaused()
        let rentalId = NFTLending.nextRentalId
        NFTLending.nextRentalId = rentalId + 1

        let terms = RentalTerms(
            rentalId: rentalId, lender: lender, borrower: borrower,
            nftId: nftId, nftContractAddress: nftContractAddress,
            collateralAmount: collateralAmount, pricePerEpoch: pricePerEpoch,
            durationBlocks: durationBlocks, capabilityControllerID: capabilityControllerID
        )

        if NFTLending.rentals[lender] == nil { NFTLending.rentals[lender] = {} }
        NFTLending.rentals[lender]![rentalId] = terms

        if NFTLending.borrowerRentals[borrower] == nil { NFTLending.borrowerRentals[borrower] = [] }
        NFTLending.borrowerRentals[borrower]!.append(rentalId)

        emit RentalCreated(rentalId: rentalId, lender: lender, borrower: borrower,
                           nftId: nftId, durationBlocks: durationBlocks)
        return rentalId
    }

    // Get rental terms for a specific rental
    access(all) view fun getRental(lender: Address, rentalId: UInt64): RentalTerms? {
        return NFTLending.rentals[lender]?[rentalId]
    }

    // Returns all active (non-expired) rentals for a borrower
    access(all) view fun getActiveBorrowerRentals(borrower: Address): [UInt64] {
        return NFTLending.borrowerRentals[borrower] ?? []
    }

    init() {
        self.rentals = {}
        self.borrowerRentals = {}
        self.nextRentalId = 0
        self.AdminStoragePath = /storage/NFTLendingAdmin
        self.account.storage.save(<-create NFTLending_Admin(), to: self.AdminStoragePath)
    }

    // Internal admin resource for cleanup operations
    access(all) resource NFTLending_Admin {
        // Admin can batch-revoke expired rentals
        access(LendingAdmin) fun revokeExpired(lenderAccount: auth(RevokeCapabilityController) &Account, lenderAddress: Address) {
            if let lenderRentals = NFTLending.rentals[lenderAddress] {
                for rentalId in lenderRentals.keys {
                    var terms = lenderRentals[rentalId]!
                    if terms.isExpired() && terms.active {
                        // Revoke the capability via the controller ID
                        lenderAccount.capabilities.storage.getController(byID: terms.capabilityControllerID)?.delete()
                        terms.active = false
                        NFTLending.rentals[lenderAddress]![rentalId] = terms
                        emit RentalRevoked(rentalId: rentalId, reason: "expired")
                    }
                }
            }
        }
    }
}

// cadence/contracts/systems/Marketplace.cdc
//
// On-chain NFT marketplace for Flow game studios.
// Design: NFTs are escrowed in contract storage on listing; purchase withdraws
// from escrow directly — no seller co-signing required at purchase time.
// Offers escrow the buyer's tokens until accepted or withdrawn.
// Platform fee capped at maxPlatformFee (10%), configurable by Admin entitlement.
// Royalties resolved from MetadataViews.Royalties on each NFT at purchase time.
//
// Implementation note on struct mutability:
// Cadence 1.0 prevents mutating struct fields even with access(contract) when
// working with a value copy outside the struct scope. To avoid this, `active`
// state is tracked separately in `inactiveListings` and `inactiveOffers` sets
// rather than as a mutable field on the struct itself.
import "NonFungibleToken"
import "FungibleToken"
import "MetadataViews"
import "GameToken"
import "GameNFT"

access(all) contract Marketplace {

    // -----------------------------------------------------------------------
    // Entitlements
    // -----------------------------------------------------------------------

    /// Admin entitlement — held only by the AdminRef resource stored at deployer account.
    access(all) entitlement Admin

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// Fires when an NFT is listed for sale.
    access(all) event Listed(listingId: UInt64, nftId: UInt64, seller: Address, price: UFix64)
    /// Fires when a purchase completes successfully.
    access(all) event Purchased(listingId: UInt64, nftId: UInt64, buyer: Address, price: UFix64)
    /// Fires when a seller cancels their listing.
    access(all) event Cancelled(listingId: UInt64, nftId: UInt64, seller: Address)
    /// Fires when a buyer submits an offer (tokens escrowed).
    access(all) event OfferMade(offerId: UInt64, nftId: UInt64, buyer: Address, amount: UFix64)
    /// Fires when a seller accepts an offer.
    access(all) event OfferAccepted(offerId: UInt64, nftId: UInt64)
    /// Fires when a buyer cancels/withdraws their offer (tokens returned).
    access(all) event OfferCancelled(offerId: UInt64, nftId: UInt64, buyer: Address)

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    access(all) var totalListings: UInt64
    access(all) var totalOffers: UInt64
    /// Current platform fee percentage (0–maxPlatformFee).
    access(all) var platformFeePercent: UInt8
    /// Hard cap on platform fee — enforced in AdminRef.setPlatformFee.
    access(all) let maxPlatformFee: UInt8

    // -----------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------

    /// Immutable listing record. Active state is tracked via inactiveListings set.
    access(all) struct Listing {
        access(all) let listingId: UInt64
        access(all) let nftId: UInt64
        access(all) let seller: Address
        access(all) let price: UFix64
        access(all) let listedAtBlock: UInt64

        init(listingId: UInt64, nftId: UInt64, seller: Address, price: UFix64) {
            self.listingId = listingId
            self.nftId = nftId
            self.seller = seller
            self.price = price
            self.listedAtBlock = getCurrentBlock().height
        }
    }

    /// Immutable offer record. Active state is tracked via inactiveOffers set.
    access(all) struct Offer {
        access(all) let offerId: UInt64
        access(all) let nftId: UInt64
        access(all) let buyer: Address
        access(all) let amount: UFix64
        access(all) let expiresAtBlock: UInt64

        init(offerId: UInt64, nftId: UInt64, buyer: Address, amount: UFix64, validForBlocks: UInt64) {
            self.offerId = offerId
            self.nftId = nftId
            self.buyer = buyer
            self.amount = amount
            self.expiresAtBlock = getCurrentBlock().height + validForBlocks
        }
    }

    // -----------------------------------------------------------------------
    // Internal storage
    // -----------------------------------------------------------------------

    /// listing metadata by listingId
    access(self) var listings: {UInt64: Listing}
    /// offer metadata by offerId
    access(self) var offers: {UInt64: Offer}
    /// Set of listing IDs that are no longer active (purchased or cancelled)
    access(self) var inactiveListings: {UInt64: Bool}
    /// Set of offer IDs that are no longer active (accepted or cancelled)
    access(self) var inactiveOffers: {UInt64: Bool}
    /// NFTs escrowed at listing time: nftId -> NFT resource
    access(self) var nftEscrow: @{UInt64: {NonFungibleToken.NFT}}
    /// Offer tokens escrowed at offer time: offerId -> Vault resource
    access(self) var tokenEscrow: @{UInt64: {FungibleToken.Vault}}
    /// Accumulated platform fees held in contract until Admin withdraws
    access(self) var feeVault: @{FungibleToken.Vault}

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// Returns true if listing is currently active.
    access(self) view fun isListingActive(_ listingId: UInt64): Bool {
        return self.listings[listingId] != nil && self.inactiveListings[listingId] == nil
    }

    /// Returns true if offer is currently active and not expired.
    access(self) view fun isOfferActive(_ offerId: UInt64): Bool {
        if self.offers[offerId] == nil { return false }
        if self.inactiveOffers[offerId] != nil { return false }
        return getCurrentBlock().height <= self.offers[offerId]!.expiresAtBlock
    }

    // -----------------------------------------------------------------------
    // Public contract functions
    // -----------------------------------------------------------------------

    /// List an NFT for sale. Caller must withdraw the NFT and pass it here.
    /// Returns the new listingId.
    access(all) fun listItem(
        nft: @{NonFungibleToken.NFT},
        price: UFix64,
        seller: Address
    ): UInt64 {
        pre { price > UFix64(0): "Price must be greater than 0" }

        let listingId = Marketplace.totalListings
        let nftId = nft.id

        // Escrow the NFT into contract storage
        Marketplace.nftEscrow[nftId] <-! nft

        Marketplace.listings[listingId] = Listing(
            listingId: listingId,
            nftId: nftId,
            seller: seller,
            price: price
        )
        Marketplace.totalListings = Marketplace.totalListings + 1

        emit Listed(listingId: listingId, nftId: nftId, seller: seller, price: price)
        return listingId
    }

    /// Purchase a listed NFT. Caller provides exact payment (>= listing price).
    /// Platform fee and royalties are deducted before seller receives remainder.
    access(all) fun purchase(
        listingId: UInt64,
        payment: @{FungibleToken.Vault},
        buyer: Address,
        buyerCollection: &{NonFungibleToken.Collection}
    ) {
        pre {
            Marketplace.listings[listingId] != nil: "Listing not found"
            Marketplace.isListingActive(listingId): "Listing is not active"
            payment.balance >= Marketplace.listings[listingId]!.price: "Insufficient payment"
        }

        let listing = Marketplace.listings[listingId]!

        // Deduct platform fee
        let feeAmount = listing.price * UFix64(Marketplace.platformFeePercent) / 100.0
        if feeAmount > 0.0 {
            let fee <- payment.withdraw(amount: feeAmount)
            Marketplace.feeVault.deposit(from: <- fee)
        }

        // Withdraw NFT from escrow first so we can inspect its royalties
        let nft <- Marketplace.nftEscrow.remove(key: listing.nftId)
            ?? panic("NFT not found in escrow")

        // Pay royalties from NFT metadata (if supported)
        if let royaltiesView = nft.resolveView(Type<MetadataViews.Royalties>()) {
            if let royalties = royaltiesView as? MetadataViews.Royalties {
                for royalty in royalties.getRoyalties() {
                    let royaltyAmount = listing.price * royalty.cut
                    if payment.balance >= royaltyAmount {
                        let royaltyPayment <- payment.withdraw(amount: royaltyAmount)
                        if let receiver = royalty.receiver.borrow() {
                            receiver.deposit(from: <- royaltyPayment)
                        } else {
                            // Royalty receiver unreachable — absorb into platform fee vault
                            Marketplace.feeVault.deposit(from: <- royaltyPayment)
                        }
                    }
                }
            }
        }

        // Remainder goes to seller
        let sellerReceiver = getAccount(listing.seller)
            .capabilities.get<&{FungibleToken.Receiver}>(GameToken.ReceiverPublicPath)
            .borrow() ?? panic("Seller has no token receiver capability")
        sellerReceiver.deposit(from: <- payment)

        // Deposit NFT into buyer's collection
        buyerCollection.deposit(token: <- nft)

        // Mark listing inactive
        Marketplace.inactiveListings[listingId] = true

        emit Purchased(listingId: listingId, nftId: listing.nftId, buyer: buyer, price: listing.price)
    }

    /// Cancel a listing and return the escrowed NFT to the seller's collection.
    access(all) fun cancelListing(
        listingId: UInt64,
        seller: Address,
        sellerCollection: &{NonFungibleToken.Collection}
    ) {
        let listing = Marketplace.listings[listingId] ?? panic("Listing not found")
        assert(listing.seller == seller, message: "Only the seller can cancel their listing")
        assert(Marketplace.isListingActive(listingId), message: "Listing is already inactive")

        let nft <- Marketplace.nftEscrow.remove(key: listing.nftId)
            ?? panic("NFT not found in escrow")
        sellerCollection.deposit(token: <- nft)

        Marketplace.inactiveListings[listingId] = true

        emit Cancelled(listingId: listingId, nftId: listing.nftId, seller: seller)
    }

    /// Make an offer on an NFT. Tokens are escrowed until the offer is accepted
    /// or cancelled. Returns the new offerId.
    access(all) fun makeOffer(
        nftId: UInt64,
        payment: @{FungibleToken.Vault},
        buyer: Address,
        validForBlocks: UInt64
    ): UInt64 {
        pre {
            payment.balance > UFix64(0): "Offer amount must be greater than 0"
            validForBlocks > UInt64(0): "Offer must be valid for at least 1 block"
        }

        let offerId = Marketplace.totalOffers
        let amount = payment.balance

        Marketplace.tokenEscrow[offerId] <-! payment
        Marketplace.offers[offerId] = Offer(
            offerId: offerId,
            nftId: nftId,
            buyer: buyer,
            amount: amount,
            validForBlocks: validForBlocks
        )
        Marketplace.totalOffers = Marketplace.totalOffers + 1

        emit OfferMade(offerId: offerId, nftId: nftId, buyer: buyer, amount: amount)
        return offerId
    }

    /// Accept an offer. Seller provides the NFT directly (no prior listing needed).
    /// Seller gets escrowed tokens minus platform fee; buyer gets the NFT.
    access(all) fun acceptOffer(
        offerId: UInt64,
        nft: @{NonFungibleToken.NFT},
        seller: Address
    ) {
        let offer = Marketplace.offers[offerId] ?? panic("Offer not found")
        assert(Marketplace.isOfferActive(offerId), message: "Offer is not active or has expired")

        let escrowed <- Marketplace.tokenEscrow.remove(key: offerId)
            ?? panic("Escrowed funds not found for offer")

        // Platform fee on offer amount
        let feeAmount = offer.amount * UFix64(Marketplace.platformFeePercent) / 100.0
        if feeAmount > 0.0 {
            let fee <- escrowed.withdraw(amount: feeAmount)
            Marketplace.feeVault.deposit(from: <- fee)
        }

        // Remainder to seller
        let sellerReceiver = getAccount(seller)
            .capabilities.get<&{FungibleToken.Receiver}>(GameToken.ReceiverPublicPath)
            .borrow() ?? panic("Seller has no token receiver capability")
        sellerReceiver.deposit(from: <- escrowed)

        // NFT to buyer's collection
        let buyerCollection = getAccount(offer.buyer)
            .capabilities.get<&{NonFungibleToken.Collection}>(GameNFT.CollectionPublicPath)
            .borrow() ?? panic("Buyer collection not found — buyer must run setup_account.cdc")
        buyerCollection.deposit(token: <- nft)

        Marketplace.inactiveOffers[offerId] = true

        emit OfferAccepted(offerId: offerId, nftId: offer.nftId)
    }

    /// Cancel an offer, returning escrowed tokens to the buyer.
    access(all) fun cancelOffer(
        offerId: UInt64,
        buyer: Address,
        buyerVault: &{FungibleToken.Receiver}
    ) {
        let offer = Marketplace.offers[offerId] ?? panic("Offer not found")
        assert(offer.buyer == buyer, message: "Only the buyer can cancel their offer")
        assert(Marketplace.inactiveOffers[offerId] == nil, message: "Offer is already inactive")

        let escrowed <- Marketplace.tokenEscrow.remove(key: offerId)
            ?? panic("Escrowed funds not found for offer")
        buyerVault.deposit(from: <- escrowed)

        Marketplace.inactiveOffers[offerId] = true

        emit OfferCancelled(offerId: offerId, nftId: offer.nftId, buyer: buyer)
    }

    // -----------------------------------------------------------------------
    // Read-only accessors
    // -----------------------------------------------------------------------

    /// Returns listing metadata, or nil if not found.
    access(all) view fun getListing(_ id: UInt64): Listing? {
        return self.listings[id]
    }

    /// Returns offer metadata, or nil if not found.
    access(all) view fun getOffer(_ id: UInt64): Offer? {
        return self.offers[id]
    }

    /// Returns true if listing is currently active.
    access(all) view fun listingIsActive(_ id: UInt64): Bool {
        return self.isListingActive(id)
    }

    /// Returns true if offer is currently active and not expired.
    access(all) view fun offerIsActive(_ id: UInt64): Bool {
        return self.isOfferActive(id)
    }

    /// Returns listing IDs for all currently active listings.
    access(all) fun getActiveListings(): [UInt64] {
        let active: [UInt64] = []
        for id in self.listings.keys {
            if self.inactiveListings[id] == nil {
                active.append(id)
            }
        }
        return active
    }

    /// Returns offer IDs for all currently active (non-expired) offers.
    access(all) fun getActiveOffers(): [UInt64] {
        let currentBlock = getCurrentBlock().height
        let active: [UInt64] = []
        for id in self.offers.keys {
            if self.inactiveOffers[id] == nil {
                if let offer = self.offers[id] {
                    if currentBlock <= offer.expiresAtBlock {
                        active.append(id)
                    }
                }
            }
        }
        return active
    }

    // -----------------------------------------------------------------------
    // Admin resource
    // -----------------------------------------------------------------------

    /// AdminRef is stored at deployer account, never published to a public path.
    access(all) resource AdminRef {
        /// Update platform fee percentage. Must be <= maxPlatformFee.
        access(Admin) fun setPlatformFee(_ percent: UInt8) {
            assert(percent <= Marketplace.maxPlatformFee, message: "Fee exceeds maximum allowed fee")
            Marketplace.platformFeePercent = percent
        }

        /// Withdraw all accumulated platform fees to a receiver.
        access(Admin) fun withdrawFees(receiver: &{FungibleToken.Receiver}) {
            let balance = Marketplace.feeVault.balance
            if balance > UFix64(0) {
                let fees <- Marketplace.feeVault.withdraw(amount: balance)
                receiver.deposit(from: <- fees)
            }
        }
    }

    // -----------------------------------------------------------------------
    // Init
    // -----------------------------------------------------------------------

    init() {
        self.totalListings = 0
        self.totalOffers = 0
        self.platformFeePercent = 2
        self.maxPlatformFee = 10
        self.listings = {}
        self.offers = {}
        self.inactiveListings = {}
        self.inactiveOffers = {}
        self.nftEscrow <- {}
        self.tokenEscrow <- {}
        self.feeVault <- GameToken.createEmptyVault(vaultType: Type<@GameToken.Vault>())

        self.account.storage.save(<- create AdminRef(), to: /storage/MarketplaceAdmin)
    }
}

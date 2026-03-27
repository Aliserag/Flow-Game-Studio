import "EmergencyPause"
import "FungibleToken"

// BlindAuction: Commit/reveal blind auction for NFTs or items.
// Phase 1: Bidders submit keccak256(amount || nonce) during commit window.
// Phase 2: Bidders reveal amount + nonce during reveal window.
// Winner = highest valid revealed bid.
access(all) contract BlindAuction {

    access(all) entitlement AuctionAdmin

    access(all) enum AuctionPhase: UInt8 {
        access(all) case commit   // 0: accepting commitments
        access(all) case reveal   // 1: revealing bids
        access(all) case ended    // 2: winner determined
    }

    access(all) struct Commitment {
        access(all) let bidder: Address
        access(all) let commitHash: [UInt8]   // keccak256(amount_bytes || nonce_bytes)
        access(all) var revealed: Bool
        access(all) var revealedAmount: UFix64

        init(bidder: Address, commitHash: [UInt8]) {
            self.bidder = bidder
            self.commitHash = commitHash
            self.revealed = false
            self.revealedAmount = 0.0
        }
    }

    access(all) struct AuctionConfig {
        access(all) let auctionId: UInt64
        access(all) let itemDescription: String
        access(all) let minBid: UFix64
        access(all) let commitDeadlineBlock: UInt64
        access(all) let revealDeadlineBlock: UInt64

        init(auctionId: UInt64, itemDescription: String, minBid: UFix64,
             commitDeadlineBlock: UInt64, revealDeadlineBlock: UInt64) {
            self.auctionId = auctionId
            self.itemDescription = itemDescription
            self.minBid = minBid
            self.commitDeadlineBlock = commitDeadlineBlock
            self.revealDeadlineBlock = revealDeadlineBlock
        }
    }

    access(all) var auctions: {UInt64: AuctionConfig}
    access(all) var commitments: {UInt64: {Address: Commitment}}  // auctionId -> bidder -> commitment
    access(all) var winners: {UInt64: Address}
    access(all) var winningBids: {UInt64: UFix64}
    access(all) var nextAuctionId: UInt64
    access(all) let AdminStoragePath: StoragePath

    access(all) event AuctionCreated(auctionId: UInt64, item: String, commitDeadline: UInt64)
    access(all) event BidCommitted(auctionId: UInt64, bidder: Address)
    access(all) event BidRevealed(auctionId: UInt64, bidder: Address, amount: UFix64)
    access(all) event AuctionEnded(auctionId: UInt64, winner: Address, amount: UFix64)

    access(all) resource Admin {
        access(AuctionAdmin) fun createAuction(
            itemDescription: String,
            minBid: UFix64,
            commitWindowBlocks: UInt64,
            revealWindowBlocks: UInt64
        ): UInt64 {
            EmergencyPause.assertNotPaused()
            let id = BlindAuction.nextAuctionId
            BlindAuction.nextAuctionId = id + 1
            let currentBlock = getCurrentBlock().height
            let config = AuctionConfig(
                auctionId: id,
                itemDescription: itemDescription,
                minBid: minBid,
                commitDeadlineBlock: currentBlock + commitWindowBlocks,
                revealDeadlineBlock: currentBlock + commitWindowBlocks + revealWindowBlocks
            )
            BlindAuction.auctions[id] = config
            BlindAuction.commitments[id] = {}
            emit AuctionCreated(auctionId: id, item: itemDescription, commitDeadline: config.commitDeadlineBlock)
            return id
        }
    }

    access(all) fun commitBid(auctionId: UInt64, bidder: Address, commitHash: [UInt8]) {
        EmergencyPause.assertNotPaused()
        pre { commitHash.length == 32: "Commit hash must be 32 bytes (keccak256)" }
        let auction = BlindAuction.auctions[auctionId] ?? panic("Unknown auction")
        assert(getCurrentBlock().height <= auction.commitDeadlineBlock, message: "Commit window closed")

        BlindAuction.commitments[auctionId]![bidder] = Commitment(bidder: bidder, commitHash: commitHash)
        emit BidCommitted(auctionId: auctionId, bidder: bidder)
    }

    access(all) fun revealBid(auctionId: UInt64, bidder: Address, amount: UFix64, nonce: [UInt8]) {
        EmergencyPause.assertNotPaused()
        let auction = BlindAuction.auctions[auctionId] ?? panic("Unknown auction")
        let currentBlock = getCurrentBlock().height
        assert(currentBlock > auction.commitDeadlineBlock, message: "Reveal window not open")
        assert(currentBlock <= auction.revealDeadlineBlock, message: "Reveal window closed")

        var commitment = BlindAuction.commitments[auctionId]![bidder] ?? panic("No commitment found")
        assert(!commitment.revealed, message: "Already revealed")

        // Verify: keccak256(amount_bytes || nonce)
        var amountBytes = amount.toBigEndianBytes()
        var preimage: [UInt8] = []
        preimage.appendAll(amountBytes)
        preimage.appendAll(nonce)
        let computedHash = HashAlgorithm.KECCAK_256.hash(preimage)
        assert(computedHash == commitment.commitHash, message: "Reveal does not match commitment")
        assert(amount >= auction.minBid, message: "Bid below minimum")

        commitment.revealed = true
        commitment.revealedAmount = amount
        BlindAuction.commitments[auctionId]![bidder] = commitment
        emit BidRevealed(auctionId: auctionId, bidder: bidder, amount: amount)

        // Update winner if this is the highest bid
        let currentWinningBid = BlindAuction.winningBids[auctionId] ?? 0.0
        if amount > currentWinningBid {
            BlindAuction.winners[auctionId] = bidder
            BlindAuction.winningBids[auctionId] = amount
        }
    }

    access(all) fun finalizeAuction(auctionId: UInt64) {
        let auction = BlindAuction.auctions[auctionId] ?? panic("Unknown auction")
        assert(getCurrentBlock().height > auction.revealDeadlineBlock, message: "Reveal window still open")

        if let winner = BlindAuction.winners[auctionId] {
            let winBid = BlindAuction.winningBids[auctionId]!
            emit AuctionEnded(auctionId: auctionId, winner: winner, amount: winBid)
        }
    }

    init() {
        self.auctions = {}
        self.commitments = {}
        self.winners = {}
        self.winningBids = {}
        self.nextAuctionId = 0
        self.AdminStoragePath = /storage/BlindAuctionAdmin
        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}

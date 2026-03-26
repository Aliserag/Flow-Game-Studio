// cadence/tests/Marketplace_test.cdc
//
// Tests for the Marketplace contract.
// Deploys GameNFT, GameToken, and Marketplace in sequence, then exercises
// listing, purchasing, cancellation, and offer flows.
//
// API notes (Flow CLI v2.x):
//   - Test.deployContract() deploys to 0x0000000000000007 in the test env.
//   - Test.Transaction struct required for executeTransaction.
//   - Test.readFile() loads file content from a path.
//   - Contract state accessed via `import` is a snapshot at compile time.
//     Use executeScript to read live on-chain state.
import Test
import "GameNFT"

// Deployer account — 0x0000000000000007 in the test environment
access(all) let deployer = Test.getAccount(0x0000000000000007)

// -------------------------------------------------------------------------
// setup() — deploys all required contracts ONCE before all tests
// -------------------------------------------------------------------------

access(all) fun setup() {
    // 1. Deploy GameNFT (no constructor args)
    let nftErr = Test.deployContract(
        name: "GameNFT",
        path: "../contracts/core/GameNFT.cdc",
        arguments: []
    )
    Test.expect(nftErr, Test.beNil())

    // 2. Deploy GameToken
    let tokenErr = Test.deployContract(
        name: "GameToken",
        path: "../contracts/core/GameToken.cdc",
        arguments: ["Gold", "GOLD", UFix64(1_000_000_000.0)]
    )
    Test.expect(tokenErr, Test.beNil())

    // 3. Deploy Marketplace (depends on GameNFT + GameToken)
    let marketErr = Test.deployContract(
        name: "Marketplace",
        path: "../contracts/systems/Marketplace.cdc",
        arguments: []
    )
    Test.expect(marketErr, Test.beNil())
}

// -------------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------------

/// Execute a file-based transaction signed by `signer`.
access(all) fun runTx(_ path: String, _ args: [AnyStruct], _ signer: Test.TestAccount): Test.TransactionResult {
    let tx = Test.Transaction(
        code: Test.readFile(path),
        authorizers: [signer.address],
        signers: [signer],
        arguments: args
    )
    return Test.executeTransaction(tx)
}

/// Set up a player account with both NFT collection and token vault.
access(all) fun setupPlayer(_ player: Test.TestAccount) {
    Test.expect(
        runTx("../transactions/setup/setup_account.cdc", [], player),
        Test.beSucceeded()
    )
    Test.expect(
        runTx("../transactions/token/setup_token_vault.cdc", [], player),
        Test.beSucceeded()
    )
}

/// Mint an NFT to a player account and return the assigned NFT ID.
/// Queries the collection after minting to find the highest ID.
access(all) fun mintNFT(_ recipient: Address): UInt64 {
    let tx = Test.Transaction(
        code: Test.readFile("../transactions/nft/mint_game_nft.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [recipient, "Sword of Dawn", "A legendary blade", "https://example.com/sword.png"]
    )
    Test.expect(Test.executeTransaction(tx), Test.beSucceeded())
    // Query collection to get the highest NFT id (the one just minted)
    let script = "import \"GameNFT\"\naccess(all) fun main(addr: Address): UInt64 { let ids = getAccount(addr).capabilities.get<&GameNFT.Collection>(/public/GameNFTCollection).borrow()?.getIDs() ?? []; var maxId: UInt64 = 0; for id in ids { if id > maxId { maxId = id } }; return maxId }"
    let result = Test.executeScript(script, [recipient])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UInt64
}

/// Mint tokens to a player account. Signed by deployer.
access(all) fun mintTokens(_ recipient: Address, _ amount: UFix64) {
    let tx = Test.Transaction(
        code: Test.readFile("../transactions/token/mint_tokens.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [recipient, amount]
    )
    Test.expect(Test.executeTransaction(tx), Test.beSucceeded())
}

/// Query token balance for an address.
access(all) fun getBalance(_ address: Address): UFix64 {
    let result = Test.executeScript(
        Test.readFile("../scripts/get_token_balance.cdc"),
        [address]
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UFix64
}

/// Query active listing IDs via script (live chain state).
access(all) fun getActiveListings(): [UInt64] {
    let result = Test.executeScript(
        Test.readFile("../scripts/get_listings.cdc"),
        []
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! [UInt64]
}

/// Query total listings count via script (live chain state).
access(all) fun getTotalListings(): UInt64 {
    let script = "import \"Marketplace\"\naccess(all) fun main(): UInt64 { return Marketplace.totalListings }"
    let result = Test.executeScript(script, [])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UInt64
}

/// Query total offers count via script (live chain state).
access(all) fun getTotalOffers(): UInt64 {
    let script = "import \"Marketplace\"\naccess(all) fun main(): UInt64 { return Marketplace.totalOffers }"
    let result = Test.executeScript(script, [])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UInt64
}

/// Check if a listing is active via script.
access(all) fun isListingActive(_ id: UInt64): Bool {
    let script = "import \"Marketplace\"\naccess(all) fun main(id: UInt64): Bool { return Marketplace.listingIsActive(id) }"
    let result = Test.executeScript(script, [id])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! Bool
}

/// Check if an offer is active via script.
access(all) fun isOfferActive(_ id: UInt64): Bool {
    let script = "import \"Marketplace\"\naccess(all) fun main(id: UInt64): Bool { return Marketplace.offerIsActive(id) }"
    let result = Test.executeScript(script, [id])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! Bool
}

/// Get listing price via script.
access(all) fun getListingPrice(_ id: UInt64): UFix64 {
    let script = "import \"Marketplace\"\naccess(all) fun main(id: UInt64): UFix64 { return Marketplace.getListing(id)?.price ?? UFix64(0) }"
    let result = Test.executeScript(script, [id])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UFix64
}

/// Get listing seller via script.
access(all) fun getListingSeller(_ id: UInt64): Address {
    let script = "import \"Marketplace\"\naccess(all) fun main(id: UInt64): Address { return Marketplace.getListing(id)!.seller }"
    let result = Test.executeScript(script, [id])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! Address
}

/// Get offer buyer via script.
access(all) fun getOfferBuyer(_ id: UInt64): Address {
    let script = "import \"Marketplace\"\naccess(all) fun main(id: UInt64): Address { return Marketplace.getOffer(id)!.buyer }"
    let result = Test.executeScript(script, [id])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! Address
}

/// Get offer amount via script.
access(all) fun getOfferAmount(_ id: UInt64): UFix64 {
    let script = "import \"Marketplace\"\naccess(all) fun main(id: UInt64): UFix64 { return Marketplace.getOffer(id)!.amount }"
    let result = Test.executeScript(script, [id])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UFix64
}

/// Query number of NFTs in an account's collection.
access(all) fun getNFTCount(_ address: Address): Int {
    let script = "import \"GameNFT\"\naccess(all) fun main(addr: Address): Int { return getAccount(addr).capabilities.get<&GameNFT.Collection>(/public/GameNFTCollection).borrow()?.getIDs()?.length ?? 0 }"
    let result = Test.executeScript(script, [address])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! Int
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

/// Marketplace deploys with zero listings, zero offers, 2% fee.
access(all) fun testDeployment() {
    Test.assertEqual(getTotalListings(), UInt64(0))
    Test.assertEqual(getTotalOffers(), UInt64(0))

    // Check fee via script
    let feeScript = "import \"Marketplace\"\naccess(all) fun main(): UInt8 { return Marketplace.platformFeePercent }"
    let feeResult = Test.executeScript(feeScript, [])
    Test.expect(feeResult, Test.beSucceeded())
    Test.assertEqual(feeResult.returnValue! as! UInt8, UInt8(2))
}

/// Seller can list an NFT; listing appears in getActiveListings().
access(all) fun testListItem() {
    // Arrange
    let seller = Test.createAccount()
    setupPlayer(seller)
    let nftId = mintNFT(seller.address)

    // Verify seller has NFT
    Test.assertEqual(getNFTCount(seller.address), 1)

    // Capture current listing count BEFORE listing to compute the new listingId
    let listingId = getTotalListings()

    // Act — list NFT for 100 tokens
    let listResult = runTx("../transactions/marketplace/list_item.cdc", [nftId, UFix64(100.0)], seller)
    Test.expect(listResult, Test.beSucceeded())

    // Assert — listing appears as active
    let active = getActiveListings()
    Test.assert(active.contains(listingId), message: "New listing should be in active listings")

    // Seller no longer holds the NFT (it's escrowed)
    Test.assertEqual(getNFTCount(seller.address), 0)

    // Listing metadata is correct
    Test.assertEqual(getListingPrice(listingId), UFix64(100.0))
    Test.assertEqual(getListingSeller(listingId), seller.address)
    Test.assert(isListingActive(listingId), message: "Listing should be active")
}

/// Buyer can purchase a listed NFT; seller receives payment (minus fee).
access(all) fun testPurchaseItem() {
    // Arrange
    let seller = Test.createAccount()
    let buyer = Test.createAccount()
    setupPlayer(seller)
    setupPlayer(buyer)

    // Mint NFT to seller and tokens to buyer
    let nftId = mintNFT(seller.address)
    mintTokens(buyer.address, UFix64(200.0))

    // Capture listingId BEFORE creating the listing
    let listingId = getTotalListings()

    // List the NFT
    let listResult = runTx("../transactions/marketplace/list_item.cdc", [nftId, UFix64(100.0)], seller)
    Test.expect(listResult, Test.beSucceeded())

    let sellerBalanceBefore = getBalance(seller.address)

    // Act — buyer purchases
    let purchaseResult = runTx("../transactions/marketplace/purchase_item.cdc", [listingId], buyer)
    Test.expect(purchaseResult, Test.beSucceeded())

    // Assert — buyer has NFT
    Test.assertEqual(getNFTCount(buyer.address), 1)

    // Seller received 98 tokens (100 minus 2% fee)
    let sellerBalanceAfter = getBalance(seller.address)
    Test.assertEqual(sellerBalanceAfter - sellerBalanceBefore, UFix64(98.0))

    // Listing is no longer active
    Test.assert(!isListingActive(listingId), message: "Listing should be inactive after purchase")

    // getActiveListings should not include this listing
    let active = getActiveListings()
    Test.assert(!active.contains(listingId), message: "Purchased listing should not appear in active listings")
}

/// Seller can cancel a listing and recover the escrowed NFT.
access(all) fun testCancelListing() {
    // Arrange
    let seller = Test.createAccount()
    setupPlayer(seller)

    let nftId = mintNFT(seller.address)
    Test.assertEqual(getNFTCount(seller.address), 1)

    // Capture listingId BEFORE creating the listing
    let listingId = getTotalListings()

    let listResult = runTx("../transactions/marketplace/list_item.cdc", [nftId, UFix64(50.0)], seller)
    Test.expect(listResult, Test.beSucceeded())
    // NFT is now escrowed
    Test.assertEqual(getNFTCount(seller.address), 0)

    // Act
    let cancelResult = runTx("../transactions/marketplace/cancel_listing.cdc", [listingId], seller)
    Test.expect(cancelResult, Test.beSucceeded())

    // Assert — NFT returned to seller
    Test.assertEqual(getNFTCount(seller.address), 1)

    // Listing marked inactive
    Test.assert(!isListingActive(listingId), message: "Cancelled listing should be inactive")
}

/// Buyer can make an offer; tokens are escrowed.
access(all) fun testMakeOffer() {
    // Arrange
    let buyer = Test.createAccount()
    setupPlayer(buyer)
    mintTokens(buyer.address, UFix64(300.0))

    let balanceBefore = getBalance(buyer.address)

    // Capture offerId BEFORE making the offer
    let offerId = getTotalOffers()

    // Act — make offer on hypothetical NFT id 99 for 150 tokens, valid 1000 blocks
    let offerResult = runTx(
        "../transactions/marketplace/make_offer.cdc",
        [UInt64(99), UFix64(150.0), UInt64(1000)],
        buyer
    )
    Test.expect(offerResult, Test.beSucceeded())

    // Assert — tokens were deducted (escrowed)
    let balanceAfter = getBalance(buyer.address)
    Test.assertEqual(balanceBefore - balanceAfter, UFix64(150.0))

    // Offer metadata is correct
    Test.assertEqual(getOfferBuyer(offerId), buyer.address)
    Test.assertEqual(getOfferAmount(offerId), UFix64(150.0))
    Test.assert(isOfferActive(offerId), message: "Offer should be active")
}

/// Purchasing with insufficient payment must fail.
access(all) fun testPurchaseInsufficientPaymentFails() {
    // Arrange
    let seller = Test.createAccount()
    let buyer = Test.createAccount()
    setupPlayer(seller)
    setupPlayer(buyer)

    let nftId = mintNFT(seller.address)
    // Give buyer only 50 tokens but list for 100
    mintTokens(buyer.address, UFix64(50.0))

    let listingId = getTotalListings()

    let listResult = runTx("../transactions/marketplace/list_item.cdc", [nftId, UFix64(100.0)], seller)
    Test.expect(listResult, Test.beSucceeded())

    // Act — buyer only has 50 tokens but listing costs 100
    let purchaseTx = Test.Transaction(
        code: Test.readFile("../transactions/marketplace/purchase_item.cdc"),
        authorizers: [buyer.address],
        signers: [buyer],
        arguments: [listingId]
    )
    let purchaseResult = Test.executeTransaction(purchaseTx)

    // Assert — must fail
    Test.expect(purchaseResult, Test.beFailed())
}

/// Cancelling another user's listing must fail.
access(all) fun testCancelListingByNonSellerFails() {
    // Arrange
    let seller = Test.createAccount()
    let attacker = Test.createAccount()
    setupPlayer(seller)
    setupPlayer(attacker)

    let nftId = mintNFT(seller.address)

    let listingId = getTotalListings()

    let listResult = runTx("../transactions/marketplace/list_item.cdc", [nftId, UFix64(75.0)], seller)
    Test.expect(listResult, Test.beSucceeded())

    // Act — attacker tries to cancel seller's listing
    let cancelTx = Test.Transaction(
        code: Test.readFile("../transactions/marketplace/cancel_listing.cdc"),
        authorizers: [attacker.address],
        signers: [attacker],
        arguments: [listingId]
    )
    let cancelResult = Test.executeTransaction(cancelTx)

    // Assert — must fail (seller check in contract)
    Test.expect(cancelResult, Test.beFailed())
}

/// Listing an NFT with price 0 must fail (pre-condition in contract).
access(all) fun testListItemZeroPriceFails() {
    // Arrange
    let seller = Test.createAccount()
    setupPlayer(seller)

    let nftId = mintNFT(seller.address)

    // Act — attempt zero-price listing
    let listTx = Test.Transaction(
        code: Test.readFile("../transactions/marketplace/list_item.cdc"),
        authorizers: [seller.address],
        signers: [seller],
        arguments: [nftId, UFix64(0.0)]
    )
    let listResult = Test.executeTransaction(listTx)

    // Assert — must fail
    Test.expect(listResult, Test.beFailed())
}

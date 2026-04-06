/// WinnerTrophy_test.cdc — Cadence 1.0 Testing Framework tests for WinnerTrophy.
///
/// Tests the NFT contract in isolation.
/// EVM integration (PrizePoolOrchestrator + COA + closeRound) is tested via Hardhat.
///
/// Tests:
///   1. testDeployment            — contract deploys, totalSupply = 0, paths set
///   2. testSetupCollection       — player can create a WinnerTrophy collection
///   3. testMintTrophy            — admin mints trophy, verify all metadata fields
///   4. testTrophyMetadataViews   — Display, Serial, Traits views resolve correctly
///   5. testCollectionTransfer    — deposit to collection, withdraw, re-deposit

import Test
import "WinnerTrophy"

// ─── Test accounts ─────────────────────────────────────────────────────────────
access(all) let deployer = Test.getAccount(0x0000000000000007)
access(all) let player1 = Test.createAccount()
access(all) let player2 = Test.createAccount()

// ─── Setup — deploy dependencies + WinnerTrophy ────────────────────────────────
access(all) fun setup() {
    // Deploy standards in dependency order
    var err = Test.deployContract(
        name: "ViewResolver",
        path: "../../../../cadence/contracts/standards/ViewResolver.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "NonFungibleToken",
        path: "../../../../cadence/contracts/standards/NonFungibleToken.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "FungibleToken",
        path: "../../../../cadence/contracts/standards/FungibleToken.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "MetadataViews",
        path: "../../../../cadence/contracts/standards/MetadataViews.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Deploy WinnerTrophy
    err = Test.deployContract(
        name: "WinnerTrophy",
        path: "../contracts/WinnerTrophy.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

// ─── Test 1: Deployment ────────────────────────────────────────────────────────
// Expected: totalSupply = 0, storage paths are set, deployer has a collection
access(all) fun testDeployment() {
    // Assert totalSupply is 0 after deploy
    let supplyResult = Test.executeScript(
        "import WinnerTrophy from \"WinnerTrophy\"\n"
        .concat("access(all) fun main(): UInt64 { return WinnerTrophy.totalSupply }\n"),
        []
    )
    Test.expect(supplyResult, Test.beSucceeded())
    let supply = supplyResult.returnValue! as! UInt64
    Test.assertEqual(supply, 0 as UInt64)

    // Assert deployer has a collection (created in init())
    let hasCollectionResult = Test.executeScript(
        "import WinnerTrophy from \"WinnerTrophy\"\n"
        .concat("access(all) fun main(addr: Address): Bool {\n")
        .concat("    let col = getAccount(addr).capabilities\n")
        .concat("        .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)\n")
        .concat("        .borrow()\n")
        .concat("    return col != nil\n")
        .concat("}\n"),
        [deployer.address]
    )
    Test.expect(hasCollectionResult, Test.beSucceeded())
    let hasCollection = hasCollectionResult.returnValue! as! Bool
    Test.assertEqual(hasCollection, true)
}

// ─── Test 2: Setup collection ──────────────────────────────────────────────────
// Expected: player1 can set up a WinnerTrophy collection via the transaction
access(all) fun testSetupCollection() {
    // Arrange + Act: run setup_trophy_collection.cdc for player1
    let setupResult = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/setup_trophy_collection.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: []
        )
    )
    Test.expect(setupResult, Test.beSucceeded())

    // Assert: player1 now has a collection (empty)
    let collectionResult = Test.executeScript(
        "import WinnerTrophy from \"WinnerTrophy\"\n"
        .concat("access(all) fun main(addr: Address): Int {\n")
        .concat("    let col = getAccount(addr).capabilities\n")
        .concat("        .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)\n")
        .concat("        .borrow()\n")
        .concat("        ?? panic(\"no collection\")\n")
        .concat("    return col.getLength()\n")
        .concat("}\n"),
        [player1.address]
    )
    Test.expect(collectionResult, Test.beSucceeded())
    let length = collectionResult.returnValue! as! Int
    Test.assertEqual(length, 0)
}

// ─── Test 3: Mint trophy ───────────────────────────────────────────────────────
// Expected: trophy minted to player1, totalSupply=1, metadata matches inputs
access(all) fun testMintTrophy() {
    // Arrange: player1 already has a collection from testSetupCollection
    // Build a transaction to mint a trophy using the deployer's Minter
    let mintCode =
        "import WinnerTrophy from \"WinnerTrophy\"\n"
        .concat("transaction(recipient: Address, roundId: UInt64, prizeAmount: String, evmWinnerAddress: String) {\n")
        .concat("    prepare(signer: auth(BorrowValue) &Account) {\n")
        .concat("        let minter = signer.storage\n")
        .concat("            .borrow<auth(WinnerTrophy.Minter) &WinnerTrophy.MinterResource>(from: WinnerTrophy.MinterStoragePath)\n")
        .concat("            ?? panic(\"no minter\")\n")
        .concat("        let trophy <- minter.mint(roundId: roundId, prizeAmount: prizeAmount, evmWinnerAddress: evmWinnerAddress)\n")
        .concat("        let recipientAcct = getAccount(recipient)\n")
        .concat("        let col = recipientAcct.capabilities\n")
        .concat("            .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)\n")
        .concat("            .borrow()\n")
        .concat("            ?? panic(\"recipient has no collection\")\n")
        .concat("        col.deposit(token: <- trophy)\n")
        .concat("        WinnerTrophy.emitMinted(id: 0, roundId: roundId, winner: recipient, prizeAmount: prizeAmount)\n")
        .concat("    }\n")
        .concat("}\n")

    let mintResult = Test.executeTransaction(
        Test.Transaction(
            code: mintCode,
            authorizers: [deployer.address],
            signers: [deployer],
            arguments: [
                player1.address,
                0 as UInt64,                      // roundId
                "500000000000000000000" as String, // prizeAmount in wei (500 tokens)
                "0xabcdef1234567890abcdef1234567890abcdef12" as String
            ]
        )
    )
    Test.expect(mintResult, Test.beSucceeded())

    // Assert: totalSupply = 1
    let supplyResult = Test.executeScript(
        "import WinnerTrophy from \"WinnerTrophy\"\n"
        .concat("access(all) fun main(): UInt64 { return WinnerTrophy.totalSupply }\n"),
        []
    )
    Test.expect(supplyResult, Test.beSucceeded())
    Test.assertEqual(supplyResult.returnValue! as! UInt64, 1 as UInt64)

    // Assert: player1's collection has 1 trophy
    let lengthResult = Test.executeScript(
        "import WinnerTrophy from \"WinnerTrophy\"\n"
        .concat("access(all) fun main(addr: Address): Int {\n")
        .concat("    let col = getAccount(addr).capabilities\n")
        .concat("        .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)\n")
        .concat("        .borrow() ?? panic(\"no collection\")\n")
        .concat("    return col.getLength()\n")
        .concat("}\n"),
        [player1.address]
    )
    Test.expect(lengthResult, Test.beSucceeded())
    Test.assertEqual(lengthResult.returnValue! as! Int, 1)

    // Assert: trophy roundId = 0
    let roundIdResult = Test.executeScript(
        "import WinnerTrophy from \"WinnerTrophy\"\n"
        .concat("access(all) fun main(addr: Address): UInt64 {\n")
        .concat("    let col = getAccount(addr).capabilities\n")
        .concat("        .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)\n")
        .concat("        .borrow() ?? panic(\"no collection\")\n")
        .concat("    let t = col.borrowTrophy(id: 0) ?? panic(\"no trophy\")\n")
        .concat("    return t.roundId\n")
        .concat("}\n"),
        [player1.address]
    )
    Test.expect(roundIdResult, Test.beSucceeded())
    Test.assertEqual(roundIdResult.returnValue! as! UInt64, 0 as UInt64)

    // Assert: trophy prizeAmount = "500000000000000000000"
    let prizeAmountResult = Test.executeScript(
        "import WinnerTrophy from \"WinnerTrophy\"\n"
        .concat("access(all) fun main(addr: Address): String {\n")
        .concat("    let col = getAccount(addr).capabilities\n")
        .concat("        .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)\n")
        .concat("        .borrow() ?? panic(\"no collection\")\n")
        .concat("    let t = col.borrowTrophy(id: 0) ?? panic(\"no trophy\")\n")
        .concat("    return t.prizeAmount\n")
        .concat("}\n"),
        [player1.address]
    )
    Test.expect(prizeAmountResult, Test.beSucceeded())
    Test.assertEqual(prizeAmountResult.returnValue! as! String, "500000000000000000000")
}

// ─── Test 4: MetadataViews ────────────────────────────────────────────────────
// Expected: Display, Serial, Traits views all return non-nil values
access(all) fun testTrophyMetadataViews() {
    // Arrange: trophy id=0 is in player1's collection from testMintTrophy

    // Assert: Display view resolves
    let displayResult = Test.executeScript(
        "import WinnerTrophy from \"WinnerTrophy\"\n"
        .concat("import MetadataViews from \"MetadataViews\"\n")
        .concat("access(all) fun main(addr: Address): String {\n")
        .concat("    let col = getAccount(addr).capabilities\n")
        .concat("        .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)\n")
        .concat("        .borrow() ?? panic(\"no collection\")\n")
        .concat("    let t = col.borrowTrophy(id: 0) ?? panic(\"no trophy\")\n")
        .concat("    let view = t.resolveView(Type<MetadataViews.Display>())\n")
        .concat("        ?? panic(\"no Display view\")\n")
        .concat("    let display = view as! MetadataViews.Display\n")
        .concat("    return display.name\n")
        .concat("}\n"),
        [player1.address]
    )
    Test.expect(displayResult, Test.beSucceeded())
    let displayName = displayResult.returnValue! as! String
    // Name should start with "Prize Pool Trophy #"
    Test.assertEqual(displayName.slice(from: 0, upTo: 19), "Prize Pool Trophy #")

    // Assert: Serial view resolves to id=0
    let serialResult = Test.executeScript(
        "import WinnerTrophy from \"WinnerTrophy\"\n"
        .concat("import MetadataViews from \"MetadataViews\"\n")
        .concat("access(all) fun main(addr: Address): UInt64 {\n")
        .concat("    let col = getAccount(addr).capabilities\n")
        .concat("        .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)\n")
        .concat("        .borrow() ?? panic(\"no collection\")\n")
        .concat("    let t = col.borrowTrophy(id: 0) ?? panic(\"no trophy\")\n")
        .concat("    let view = t.resolveView(Type<MetadataViews.Serial>())\n")
        .concat("        ?? panic(\"no Serial view\")\n")
        .concat("    return (view as! MetadataViews.Serial).number\n")
        .concat("}\n"),
        [player1.address]
    )
    Test.expect(serialResult, Test.beSucceeded())
    Test.assertEqual(serialResult.returnValue! as! UInt64, 0 as UInt64)
}

// ─── Test 5: Collection transfer ──────────────────────────────────────────────
// Expected: withdraw from player1's collection, deposit into player2's collection
access(all) fun testCollectionTransfer() {
    // Arrange: setup player2 collection
    let setup2Result = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/setup_trophy_collection.cdc"),
            authorizers: [player2.address],
            signers: [player2],
            arguments: []
        )
    )
    Test.expect(setup2Result, Test.beSucceeded())

    // Act: player1 withdraws trophy id=0 and deposits to player2
    let transferCode =
        "import NonFungibleToken from \"NonFungibleToken\"\n"
        .concat("import WinnerTrophy from \"WinnerTrophy\"\n")
        .concat("transaction(recipient: Address, trophyId: UInt64) {\n")
        .concat("    prepare(signer: auth(BorrowValue) &Account) {\n")
        .concat("        let col = signer.storage\n")
        .concat("            .borrow<auth(NonFungibleToken.Withdraw) &WinnerTrophy.Collection>(\n")
        .concat("                from: WinnerTrophy.CollectionStoragePath\n")
        .concat("            ) ?? panic(\"no collection\")\n")
        .concat("        let trophy <- col.withdraw(withdrawID: trophyId)\n")
        .concat("        let recipientCol = getAccount(recipient).capabilities\n")
        .concat("            .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)\n")
        .concat("            .borrow() ?? panic(\"no recipient collection\")\n")
        .concat("        recipientCol.deposit(token: <- trophy)\n")
        .concat("    }\n")
        .concat("}\n")

    let transferResult = Test.executeTransaction(
        Test.Transaction(
            code: transferCode,
            authorizers: [player1.address],
            signers: [player1],
            arguments: [player2.address, 0 as UInt64]
        )
    )
    Test.expect(transferResult, Test.beSucceeded())

    // Assert: player1 has 0 trophies
    let p1CountResult = Test.executeScript(
        "import WinnerTrophy from \"WinnerTrophy\"\n"
        .concat("access(all) fun main(addr: Address): Int {\n")
        .concat("    let col = getAccount(addr).capabilities\n")
        .concat("        .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)\n")
        .concat("        .borrow() ?? panic(\"no collection\")\n")
        .concat("    return col.getLength()\n")
        .concat("}\n"),
        [player1.address]
    )
    Test.expect(p1CountResult, Test.beSucceeded())
    Test.assertEqual(p1CountResult.returnValue! as! Int, 0)

    // Assert: player2 has 1 trophy (id=0)
    let p2CountResult = Test.executeScript(
        "import WinnerTrophy from \"WinnerTrophy\"\n"
        .concat("access(all) fun main(addr: Address): [UInt64] {\n")
        .concat("    let col = getAccount(addr).capabilities\n")
        .concat("        .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)\n")
        .concat("        .borrow() ?? panic(\"no collection\")\n")
        .concat("    return col.getIDs()\n")
        .concat("}\n"),
        [player2.address]
    )
    Test.expect(p2CountResult, Test.beSucceeded())
    let p2Ids = p2CountResult.returnValue! as! [UInt64]
    Test.assertEqual(p2Ids.length, 1)
    Test.assertEqual(p2Ids[0], 0 as UInt64)
}

// NFTBattler_test.cdc — Cadence 1.0 Testing Framework tests for the NFT Battler example.
//
// Tests:
// 1. testSetupAndMint — setup accounts, mint fighters, verify collection IDs
// 2. testAttachPowerUp — mint powerup, attach to fighter, verify effectivePower increases
// 3. testBattle_AttackBeatsDefense — Attack fighter beats Defense fighter (RPS rule)
// 4. testBattle_DefenseBeatingMagic — Defense fighter beats Magic fighter (RPS rule)
// 5. testBattle_SameClassPowerTiebreak — higher power wins when same class
//
// NOTE: Tests run sequentially in order and share state (same emulator instance).
// Fighter IDs are allocated globally: deployer already has 0 NFTs, so each mint
// produces IDs in order starting from 0.

import Test
import "Fighter"
import "PowerUp"
import "BattleArena"

access(all) let deployer = Test.getAccount(0x0000000000000007)
access(all) let player1 = Test.createAccount()
access(all) let player2 = Test.createAccount()

access(all) fun setup() {
    // Deploy standard contracts in dependency order.
    // Paths are relative to this test file at cadence/tests/
    // ../../../../ goes up to the flow-blockchain-studio root.
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

    // MetadataViews requires FungibleToken as a transitive import
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

    // PowerUp must be deployed before Fighter (Fighter imports PowerUp)
    err = Test.deployContract(
        name: "PowerUp",
        path: "../contracts/PowerUp.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "Fighter",
        path: "../contracts/Fighter.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "BattleArena",
        path: "../contracts/BattleArena.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

// ─── Test 1: Setup accounts and mint starter fighters ─────────────────────────
// Expected state after: player1 has fighter id=0 (Attack, 50), player2 has id=1 (Defense, 40)
access(all) fun testSetupAndMint() {
    // Arrange: setup collections for both players
    let setupResult1 = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/setup_account.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: []
        )
    )
    Test.expect(setupResult1, Test.beSucceeded())

    let setupResult2 = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/setup_account.cdc"),
            authorizers: [player2.address],
            signers: [player2],
            arguments: []
        )
    )
    Test.expect(setupResult2, Test.beSucceeded())

    // Act: mint Attack fighter for player1 (will be id=0, basePower=50)
    let mint1 = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/mint_starter.cdc"),
            authorizers: [deployer.address],
            signers: [deployer],
            arguments: [player1.address, "Blaze", 0 as UInt8, 50 as UInt64]
        )
    )
    Test.expect(mint1, Test.beSucceeded())

    // Mint Defense fighter for player2 (will be id=1, basePower=40)
    let mint2 = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/mint_starter.cdc"),
            authorizers: [deployer.address],
            signers: [deployer],
            arguments: [player2.address, "Granite", 1 as UInt8, 40 as UInt64]
        )
    )
    Test.expect(mint2, Test.beSucceeded())

    // Assert: verify player1's collection contains fighter id=0
    // Script returns [UInt64] — the list of NFT IDs in the collection
    let p1IdsResult = Test.executeScript(
        "import Fighter from \"Fighter\"\n"
        .concat("access(all) fun main(addr: Address): [UInt64] {\n")
        .concat("    let col = getAccount(addr).capabilities.get<&Fighter.Collection>(Fighter.CollectionPublicPath).borrow()\n")
        .concat("        ?? panic(\"no collection\")\n")
        .concat("    return col.getIDs()\n")
        .concat("}\n"),
        [player1.address]
    )
    Test.expect(p1IdsResult, Test.beSucceeded())
    let p1Ids = p1IdsResult.returnValue! as! [UInt64]
    Test.assertEqual(p1Ids.length, 1)
    Test.assertEqual(p1Ids[0], 0 as UInt64)

    // Assert: player2's collection contains fighter id=1
    let p2IdsResult = Test.executeScript(
        "import Fighter from \"Fighter\"\n"
        .concat("access(all) fun main(addr: Address): [UInt64] {\n")
        .concat("    let col = getAccount(addr).capabilities.get<&Fighter.Collection>(Fighter.CollectionPublicPath).borrow()\n")
        .concat("        ?? panic(\"no collection\")\n")
        .concat("    return col.getIDs()\n")
        .concat("}\n"),
        [player2.address]
    )
    Test.expect(p2IdsResult, Test.beSucceeded())
    let p2Ids = p2IdsResult.returnValue! as! [UInt64]
    Test.assertEqual(p2Ids.length, 1)
    Test.assertEqual(p2Ids[0], 1 as UInt64)

    // Assert: fighter id=0 has wins=0, losses=0
    let recordResult = Test.executeScript(
        Test.readFile("../scripts/get_battle_record.cdc"),
        [player1.address, 0 as UInt64]
    )
    Test.expect(recordResult, Test.beSucceeded())
    // BattleRecord struct fields accessed as {String: AnyStruct}
    let record = recordResult.returnValue! as! {String: AnyStruct}
    Test.assertEqual(record["wins"]! as! UInt64, 0 as UInt64)
    Test.assertEqual(record["losses"]! as! UInt64, 0 as UInt64)
    Test.assertEqual(record["totalBattles"]! as! UInt64, 0 as UInt64)
}

// ─── Test 2: Attach a PowerUp to a Fighter and verify effectivePower ──────────
// Setup: fighter id=0 has basePower=50; mint a Gem powerup (+20) for player1
// After attach: effectivePower should be 70
access(all) fun testAttachPowerUp() {
    // Arrange: mint a Gem power-up (+20 bonusPower) for player1 (powerup id=0)
    let mintPU = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/mint_powerup.cdc"),
            authorizers: [deployer.address],
            signers: [deployer],
            arguments: [player1.address, "Ancient Gem", 3 as UInt8, 20 as UInt64]
        )
    )
    Test.expect(mintPU, Test.beSucceeded())

    // Assert before: effectivePower = basePower = 50 (no attachment yet)
    let beforeResult = Test.executeScript(
        "import Fighter from \"Fighter\"\n"
        .concat("import PowerUp from \"PowerUp\"\n")
        .concat("access(all) fun main(addr: Address, fid: UInt64): UInt64 {\n")
        .concat("    let col = getAccount(addr).capabilities.get<&Fighter.Collection>(Fighter.CollectionPublicPath).borrow()\n")
        .concat("        ?? panic(\"no collection\")\n")
        .concat("    let f = col.borrowFighterNFT(id: fid) ?? panic(\"not found\")\n")
        .concat("    return f.effectivePower()\n")
        .concat("}\n"),
        [player1.address, 0 as UInt64]
    )
    Test.expect(beforeResult, Test.beSucceeded())
    let powerBefore = beforeResult.returnValue! as! UInt64
    Test.assertEqual(powerBefore, 50 as UInt64)

    // Act: attach powerup id=0 to fighter id=0
    let attachResult = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/attach_powerup.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: [0 as UInt64, 0 as UInt64]
        )
    )
    Test.expect(attachResult, Test.beSucceeded())

    // Assert after: effectivePower = 50 + 20 = 70
    let afterResult = Test.executeScript(
        "import Fighter from \"Fighter\"\n"
        .concat("import PowerUp from \"PowerUp\"\n")
        .concat("access(all) fun main(addr: Address, fid: UInt64): UInt64 {\n")
        .concat("    let col = getAccount(addr).capabilities.get<&Fighter.Collection>(Fighter.CollectionPublicPath).borrow()\n")
        .concat("        ?? panic(\"no collection\")\n")
        .concat("    let f = col.borrowFighterNFT(id: fid) ?? panic(\"not found\")\n")
        .concat("    return f.effectivePower()\n")
        .concat("}\n"),
        [player1.address, 0 as UInt64]
    )
    Test.expect(afterResult, Test.beSucceeded())
    let powerAfter = afterResult.returnValue! as! UInt64
    Test.assertEqual(powerAfter, 70 as UInt64)
}

// ─── Test 3: Attack beats Defense (RPS rule) ─────────────────────────────────
// Setup state: player1 has fighter 0 (Attack, power 70). We mint a Defense fighter
// for player1 as opponent (id=2, basePower=30). Battle 0 vs 2 — Attack should win.
access(all) fun testBattle_AttackBeatsDefense() {
    // Arrange: mint a Defense fighter for player1 (id=2, basePower=30)
    let mintDefense = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/mint_starter.cdc"),
            authorizers: [deployer.address],
            signers: [deployer],
            arguments: [player1.address, "StonePillar", 1 as UInt8, 30 as UInt64]
        )
    )
    Test.expect(mintDefense, Test.beSucceeded())

    // Act: battle fighter 0 (Attack, 70 power) vs fighter 2 (Defense, 30 power)
    let battleResult = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/battle.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: [0 as UInt64, 2 as UInt64]
        )
    )
    Test.expect(battleResult, Test.beSucceeded())

    // Assert: fighter 0 (Attack) wins — it now has 1 win, 0 losses
    let f0Record = Test.executeScript(
        Test.readFile("../scripts/get_battle_record.cdc"),
        [player1.address, 0 as UInt64]
    )
    Test.expect(f0Record, Test.beSucceeded())
    let f0 = f0Record.returnValue! as! {String: AnyStruct}
    Test.assertEqual(f0["wins"]! as! UInt64, 1 as UInt64)
    Test.assertEqual(f0["losses"]! as! UInt64, 0 as UInt64)

    // Assert: fighter 2 (Defense) loses
    let f2Record = Test.executeScript(
        Test.readFile("../scripts/get_battle_record.cdc"),
        [player1.address, 2 as UInt64]
    )
    Test.expect(f2Record, Test.beSucceeded())
    let f2 = f2Record.returnValue! as! {String: AnyStruct}
    Test.assertEqual(f2["wins"]! as! UInt64, 0 as UInt64)
    Test.assertEqual(f2["losses"]! as! UInt64, 1 as UInt64)
}

// ─── Test 4: Defense beats Magic (RPS rule) ───────────────────────────────────
// Setup state: fighter 2 is Defense (basePower=30, 0W-1L from prior test)
// Mint a Magic fighter for player1 (id=3, basePower=35). Battle 2 vs 3.
// Defense (1) beats Magic (2): (1+1)%3=2 == Magic(2) → Defense wins regardless of power.
access(all) fun testBattle_DefenseBeatingMagic() {
    // Arrange: mint a Magic fighter for player1 (id=3, basePower=35)
    let mintMagic = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/mint_starter.cdc"),
            authorizers: [deployer.address],
            signers: [deployer],
            arguments: [player1.address, "SpellCaster", 2 as UInt8, 35 as UInt64]
        )
    )
    Test.expect(mintMagic, Test.beSucceeded())

    // Act: battle fighter 2 (Defense, 30 power) vs fighter 3 (Magic, 35 power)
    // Defense beats Magic despite lower power — class advantage overrides power
    let battleResult = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/battle.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: [2 as UInt64, 3 as UInt64]
        )
    )
    Test.expect(battleResult, Test.beSucceeded())

    // Assert: fighter 2 (Defense) wins — now has 1W-1L
    let f2Record = Test.executeScript(
        Test.readFile("../scripts/get_battle_record.cdc"),
        [player1.address, 2 as UInt64]
    )
    Test.expect(f2Record, Test.beSucceeded())
    let f2 = f2Record.returnValue! as! {String: AnyStruct}
    Test.assertEqual(f2["wins"]! as! UInt64, 1 as UInt64)

    // Assert: fighter 3 (Magic) loses — has 0W-1L
    let f3Record = Test.executeScript(
        Test.readFile("../scripts/get_battle_record.cdc"),
        [player1.address, 3 as UInt64]
    )
    Test.expect(f3Record, Test.beSucceeded())
    let f3 = f3Record.returnValue! as! {String: AnyStruct}
    Test.assertEqual(f3["losses"]! as! UInt64, 1 as UInt64)
}

// ─── Test 5: Same class — higher effectivePower wins ──────────────────────────
// Mint two Attack fighters: id=4 (power=25) and id=5 (power=60).
// Battle 4 vs 5 — same class, power decides — fighter 4 (25) should lose.
access(all) fun testBattle_SameClassPowerTiebreak() {
    // Arrange: mint two Attack fighters with different powers
    let mintWeak = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/mint_starter.cdc"),
            authorizers: [deployer.address],
            signers: [deployer],
            arguments: [player1.address, "WeakAttacker", 0 as UInt8, 25 as UInt64]
        )
    )
    Test.expect(mintWeak, Test.beSucceeded())

    let mintStrong = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/mint_starter.cdc"),
            authorizers: [deployer.address],
            signers: [deployer],
            arguments: [player1.address, "StrongAttacker", 0 as UInt8, 60 as UInt64]
        )
    )
    Test.expect(mintStrong, Test.beSucceeded())

    // Act: battle fighter 4 (Attack, 25) vs fighter 5 (Attack, 60)
    let battleResult = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/battle.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: [4 as UInt64, 5 as UInt64]
        )
    )
    Test.expect(battleResult, Test.beSucceeded())

    // Assert: fighter 4 (lower power) loses
    let f4Record = Test.executeScript(
        Test.readFile("../scripts/get_battle_record.cdc"),
        [player1.address, 4 as UInt64]
    )
    Test.expect(f4Record, Test.beSucceeded())
    let f4 = f4Record.returnValue! as! {String: AnyStruct}
    Test.assertEqual(f4["losses"]! as! UInt64, 1 as UInt64)
    Test.assertEqual(f4["wins"]! as! UInt64, 0 as UInt64)

    // Assert: fighter 5 (higher power) wins
    let f5Record = Test.executeScript(
        Test.readFile("../scripts/get_battle_record.cdc"),
        [player1.address, 5 as UInt64]
    )
    Test.expect(f5Record, Test.beSucceeded())
    let f5 = f5Record.returnValue! as! {String: AnyStruct}
    Test.assertEqual(f5["wins"]! as! UInt64, 1 as UInt64)
    Test.assertEqual(f5["losses"]! as! UInt64, 0 as UInt64)
}

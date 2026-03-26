// cadence/tests/Achievement_test.cdc
//
// Tests for the Achievement contract.
//
// Covers:
//   - testDeployment: totalAchievements == 0
//   - testGrantAchievement: grant works, collection has the NFT
//   - testGrantDuplicateFails: second grant of same type to same player fails
//   - testTransferFails: attempting to withdraw from collection panics

import Test
import "Achievement"

// Deployer account — 0x0000000000000007 in the test environment
access(all) let deployer = Test.getAccount(0x0000000000000007)

// -------------------------------------------------------------------------
// setup() — deploys Achievement before all tests
// -------------------------------------------------------------------------

access(all) fun setup() {
    let err = Test.deployContract(
        name: "Achievement",
        path: "../contracts/systems/Achievement.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
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

/// Query totalAchievements via script.
access(all) fun getTotalAchievements(): UInt64 {
    let result = Test.executeScript(
        "import \"Achievement\"\naccess(all) fun main(): UInt64 { return Achievement.totalAchievements }",
        []
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UInt64
}

/// Query number of achievements in a player's collection via script.
access(all) fun getCollectionLength(_ player: Address): Int {
    let result = Test.executeScript(
        "import \"Achievement\"\naccess(all) fun main(player: Address): Int { let col = getAccount(player).capabilities.get<&Achievement.AchievementCollection>(Achievement.CollectionPublicPath).borrow() ?? panic(\"no collection\"); return col.getLength() }",
        [player]
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! Int
}

/// Check whether a player has a specific achievement type via script.
access(all) fun hasAchievement(_ player: Address, _ achievementType: String): Bool {
    let result = Test.executeScript(
        "import \"Achievement\"\naccess(all) fun main(player: Address, t: String): Bool { return Achievement.hasAchievement(player: player, achievementType: t) }",
        [player, achievementType]
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! Bool
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

/// Achievement contract deploys with zero achievements.
access(all) fun testDeployment() {
    // Assert
    Test.assertEqual(getTotalAchievements(), UInt64(0))
}

/// Deployer can grant an achievement to a player who has set up their collection.
access(all) fun testGrantAchievement() {
    // Arrange — set up player collection
    let player = Test.createAccount()
    Test.expect(
        runTx("../transactions/achievement/setup_achievement_collection.cdc", [], player),
        Test.beSucceeded()
    )

    let beforeTotal = getTotalAchievements()

    // Act — deployer grants achievement
    let grantResult = runTx(
        "../transactions/achievement/grant_achievement.cdc",
        [
            player.address,   // player
            "first_kill",     // achievementType
            "First Kill",     // name
            "Defeat your first enemy"  // description
        ],
        deployer
    )
    Test.expect(grantResult, Test.beSucceeded())

    // Assert
    Test.assertEqual(getTotalAchievements(), beforeTotal + UInt64(1))
    Test.assertEqual(getCollectionLength(player.address), 1)
    Test.assert(hasAchievement(player.address, "first_kill"), message: "Player should have first_kill")
}

/// Granting the same achievement type twice to the same player should fail.
access(all) fun testGrantDuplicateFails() {
    // Arrange — set up a new player and grant once
    let player = Test.createAccount()
    Test.expect(
        runTx("../transactions/achievement/setup_achievement_collection.cdc", [], player),
        Test.beSucceeded()
    )

    Test.expect(
        runTx(
            "../transactions/achievement/grant_achievement.cdc",
            [player.address, "speedrun", "Speedrunner", "Complete in under 5 minutes"],
            deployer
        ),
        Test.beSucceeded()
    )

    // Act — attempt duplicate grant
    let duplicateTx = Test.Transaction(
        code: Test.readFile("../transactions/achievement/grant_achievement.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [player.address, "speedrun", "Speedrunner", "Complete in under 5 minutes"]
    )
    let result = Test.executeTransaction(duplicateTx)

    // Assert — must fail
    Test.expect(result, Test.beFailed())
}

/// Attempting to withdraw from an AchievementCollection should panic (soulbound).
access(all) fun testTransferFails() {
    // Arrange — set up player and grant an achievement
    let player = Test.createAccount()
    Test.expect(
        runTx("../transactions/achievement/setup_achievement_collection.cdc", [], player),
        Test.beSucceeded()
    )

    Test.expect(
        runTx(
            "../transactions/achievement/grant_achievement.cdc",
            [player.address, "untransferrable", "No Transfer", "Cannot be transferred"],
            deployer
        ),
        Test.beSucceeded()
    )

    // Act — attempt withdraw from collection (should panic with "Soulbound: cannot transfer")
    let withdrawTx = Test.Transaction(
        code: "import \"Achievement\"\ntransaction { prepare(s: auth(Storage) &Account) { let col = s.storage.borrow<&Achievement.AchievementCollection>(from: Achievement.CollectionStoragePath) ?? panic(\"no collection\"); let nft <- col.withdraw(id: 0); destroy nft } }",
        authorizers: [player.address],
        signers: [player],
        arguments: []
    )
    let result = Test.executeTransaction(withdrawTx)

    // Assert — must fail (panic in withdraw)
    Test.expect(result, Test.beFailed())
}

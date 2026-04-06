// cadence/tests/SeasonPass_test.cdc
import Test
import "SeasonPass"
import "EmergencyPause"

// Deployer account — holds Admin resource at 0x0000000000000007
access(all) let deployer = Test.getAccount(0x0000000000000007)

access(all) fun setup() {
    // 1. Deploy GameToken (required by SeasonPass)
    let tokenErr = Test.deployContract(
        name: "GameToken",
        path: "../contracts/core/GameToken.cdc",
        arguments: ["Gold", "GOLD", UFix64(1_000_000_000.0)]
    )
    Test.expect(tokenErr, Test.beNil())

    // 2. Deploy Scheduler (required by SeasonPass)
    let schedulerErr = Test.deployContract(
        name: "Scheduler",
        path: "../contracts/systems/Scheduler.cdc",
        arguments: []
    )
    Test.expect(schedulerErr, Test.beNil())

    // 3. Deploy EmergencyPause (required by SeasonPass)
    let pauseErr = Test.deployContract(
        name: "EmergencyPause",
        path: "../contracts/systems/EmergencyPause.cdc",
        arguments: []
    )
    Test.expect(pauseErr, Test.beNil())

    // 4. Deploy SeasonPass
    let seasonErr = Test.deployContract(
        name: "SeasonPass",
        path: "../contracts/liveops/SeasonPass.cdc",
        arguments: []
    )
    Test.expect(seasonErr, Test.beNil())
}

access(all) fun testSeasonLifecycle() {
    // Start a season using existing transaction
    // start_season.cdc args: (name: String, startEpoch: UInt64, endEpoch: UInt64, maxTier: UInt8, xpPerTier: UFix64)
    let startTx = Test.Transaction(
        code: Test.readFile("../transactions/liveops/start_season.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: ["Season 1", UInt64(0), UInt64(100), UInt8(10), UFix64(100.0)]
    )
    Test.expect(Test.executeTransaction(startTx), Test.beSucceeded())

    // Read activeSeason.name via script (live state — avoids String vs String? mismatch)
    let nameResult = Test.executeScript(
        "import SeasonPass from 0x0000000000000007\n"
            .concat("access(all) fun main(): String {\n")
            .concat("    return SeasonPass.activeSeason?.name ?? \"\"\n")
            .concat("}"),
        []
    )
    Test.expect(nameResult, Test.beSucceeded())
    Test.assertEqual("Season 1", nameResult.returnValue! as! String)

    // Award XP using the award_xp transaction
    // award_xp.cdc args: (player: Address, amount: UFix64)
    let xpTx = Test.Transaction(
        code: Test.readFile("../transactions/liveops/award_xp.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [deployer.address, UFix64(250.0)]
    )
    Test.expect(Test.executeTransaction(xpTx), Test.beSucceeded())

    // Read xp and tier via script (live state)
    let xpResult = Test.executeScript(
        "import SeasonPass from 0x0000000000000007\n"
            .concat("access(all) fun main(player: Address): UFix64 {\n")
            .concat("    return SeasonPass.playerProgress[player]?.xp ?? 0.0\n")
            .concat("}"),
        [deployer.address]
    )
    Test.expect(xpResult, Test.beSucceeded())
    Test.assertEqual(UFix64(250.0), xpResult.returnValue! as! UFix64)

    let tierResult = Test.executeScript(
        "import SeasonPass from 0x0000000000000007\n"
            .concat("access(all) fun main(player: Address): UInt8 {\n")
            .concat("    return SeasonPass.playerProgress[player]?.currentTier ?? 0\n")
            .concat("}"),
        [deployer.address]
    )
    Test.expect(tierResult, Test.beSucceeded())
    Test.assertEqual(UInt8(2), tierResult.returnValue! as! UInt8)  // 250 XP / 100 per tier = tier 2
}

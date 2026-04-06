// cadence/tests/Scheduler_test.cdc
import Test
import "Scheduler"

access(all) fun setup() {
    let err = Test.deployContract(
        name: "Scheduler",
        path: "../contracts/systems/Scheduler.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all) fun testDeployment() {
    Test.assertEqual(Scheduler.currentEpoch, UInt64(0))
    Test.assertEqual(Scheduler.epochBlockLength, UInt64(1000))
}

access(all) fun testEpochAdvancesAfterBlocks() {
    // The Cadence Testing Framework does not have Test.moveTime().
    // Advance blocks by committing empty blocks until the epoch threshold is met.
    var i = 0
    while i < 1001 {
        Test.commitBlock()
        i = i + 1
    }

    // process_epoch.cdc has no prepare block — zero authorizers needed
    let tx = Test.Transaction(
        code: Test.readFile("../transactions/scheduler/process_epoch.cdc"),
        authorizers: [],
        signers: [],
        arguments: []
    )
    let txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    // Read live state via script to avoid import-time snapshot
    let result = Test.executeScript(
        "import Scheduler from 0x0000000000000007\naccess(all) fun main(): UInt64 { return Scheduler.currentEpoch }",
        []
    )
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual(result.returnValue! as! UInt64, UInt64(1))
}

// cadence/tests/Scheduler_test.cdc
import Test
import "Scheduler"

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

    let txResult = Test.executeTransaction(
        "../transactions/scheduler/process_epoch.cdc",
        [],
        Test.getAccount(0x0000000000000007)
    )
    Test.expect(txResult, Test.beSucceeded())
    Test.assertEqual(Scheduler.currentEpoch, UInt64(1))
}

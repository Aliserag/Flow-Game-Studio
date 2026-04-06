// cadence/tests/EmergencyPause_test.cdc
import Test
import "EmergencyPause"

access(all) let admin = Test.getAccount(0x0000000000000007)

access(all) fun setup() {
    let err = Test.deployContract(
        name: "EmergencyPause",
        path: "../contracts/systems/EmergencyPause.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all) fun getIsPaused(): Bool {
    let result = Test.executeScript(
        "import EmergencyPause from 0x0000000000000007\naccess(all) fun main(): Bool { return EmergencyPause.isPaused }",
        []
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! Bool
}

access(all) fun testPauseBlocksTransactions() {
    // Should succeed before pause
    Test.assertEqual(false, getIsPaused())

    // Pause the system using the existing transaction
    let tx = Test.Transaction(
        code: Test.readFile("../transactions/admin/pause_system.cdc"),
        authorizers: [admin.address],
        signers: [admin],
        arguments: ["test pause"]
    )
    Test.expect(Test.executeTransaction(tx), Test.beSucceeded())

    // Read live state via script
    Test.assertEqual(true, getIsPaused())

    // assertNotPaused should now panic
    Test.expectFailure(fun() { EmergencyPause.assertNotPaused() }, errorMessageSubstring: "System paused")
}

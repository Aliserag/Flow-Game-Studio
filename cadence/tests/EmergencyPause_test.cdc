import Test
import "EmergencyPause"

access(all) fun testPauseBlocksTransactions() {
    let admin = Test.getAccount(0x0000000000000001)
    Test.deployContract(name: "EmergencyPause", path: "../contracts/systems/EmergencyPause.cdc", arguments: [])

    // Should succeed before pause
    EmergencyPause.assertNotPaused()

    // Pause the system
    let tx = Test.Transaction(
        code: `
            import "EmergencyPause"
            transaction {
                prepare(signer: auth(BorrowValue) &Account) {
                    let a = signer.storage.borrow<auth(EmergencyPause.Pauser) &EmergencyPause.Admin>(
                        from: EmergencyPause.AdminStoragePath) ?? panic("no admin")
                    a.pause(reason: "test pause", by: signer.address)
                }
            }
        `,
        args: [],
        signers: [admin]
    )
    Test.expect(Test.executeTransaction(tx), Test.beSucceeded())

    Test.assertEqual(true, EmergencyPause.isPaused)

    // assertNotPaused should now panic
    Test.expectFailure(fun() { EmergencyPause.assertNotPaused() }, errorMessageSubstring: "System paused")
}

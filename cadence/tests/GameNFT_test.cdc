// cadence/tests/GameNFT_test.cdc
import Test
import "GameNFT"

access(all) fun testContractDeployment() {
    Test.assert(GameNFT.totalSupply == 0, message: "Initial supply should be 0")
}

access(all) fun testMinterInStorage() {
    // The Minter resource is intentionally NOT published to any public path (security design).
    // Verify it exists in deployer storage instead.
    let admin = Test.getAccount(0x0000000000000007)
    let minter = admin.storage.borrow<&GameNFT.Minter>(from: GameNFT.MinterStoragePath)
    Test.assert(minter != nil, message: "Minter should be in deployer storage")
}

access(all) fun testCollectionSetup() {
    let player = Test.createAccount()
    let txResult = Test.executeTransaction(
        "../transactions/setup/setup_account.cdc",
        [],
        player
    )
    Test.expect(txResult, Test.beSucceeded())

    let ids = player.capabilities
        .get<&GameNFT.Collection>(/public/GameNFTCollection)
        .borrow()?.getIDs() ?? []
    Test.assertEqual(ids.length, 0)
}

// cadence/tests/GameNFT_test.cdc
import Test
import "GameNFT"

access(all) let deployer = Test.getAccount(0x0000000000000007)

access(all) fun setup() {
    let err = Test.deployContract(
        name: "GameNFT",
        path: "../contracts/core/GameNFT.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all) fun testContractDeployment() {
    Test.assert(GameNFT.totalSupply == 0, message: "Initial supply should be 0")
}

access(all) fun testMinterCanMint() {
    // Verify the deployer can mint (implicitly tests Minter is in storage)
    let player = Test.createAccount()

    // Setup player collection
    let setupTx = Test.Transaction(
        code: Test.readFile("../transactions/setup/setup_account.cdc"),
        authorizers: [player.address],
        signers: [player],
        arguments: []
    )
    Test.expect(Test.executeTransaction(setupTx), Test.beSucceeded())

    // Mint NFT to player
    let mintTx = Test.Transaction(
        code: Test.readFile("../transactions/nft/mint_game_nft.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [player.address, "Sword", "A mighty sword", "https://example.com/sword.png"]
    )
    Test.expect(Test.executeTransaction(mintTx), Test.beSucceeded())

    // Supply should be 1 now — read via script to get live state
    let supplyResult = Test.executeScript(
        "import GameNFT from 0x0000000000000007\naccess(all) fun main(): UInt64 { return GameNFT.totalSupply }",
        []
    )
    Test.expect(supplyResult, Test.beSucceeded())
    Test.assertEqual(supplyResult.returnValue! as! UInt64, UInt64(1))
}

access(all) fun testCollectionSetup() {
    let player = Test.createAccount()
    let setupTx = Test.Transaction(
        code: Test.readFile("../transactions/setup/setup_account.cdc"),
        authorizers: [player.address],
        signers: [player],
        arguments: []
    )
    Test.expect(Test.executeTransaction(setupTx), Test.beSucceeded())

    // Verify via script that collection is empty
    let result = Test.executeScript(
        "import GameNFT from 0x0000000000000007\n"
        .concat("access(all) fun main(addr: Address): Int {\n")
        .concat("    let col = getAccount(addr).capabilities\n")
        .concat("        .borrow<&GameNFT.Collection>(GameNFT.CollectionPublicPath)\n")
        .concat("    if col == nil { return -1 }\n")
        .concat("    return col!.getIDs().length\n")
        .concat("}"),
        [player.address]
    )
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual(result.returnValue! as! Int, 0)
}

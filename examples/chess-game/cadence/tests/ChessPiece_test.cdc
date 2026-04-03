import Test
import "ChessPiece"

access(all) let deployer = Test.getAccount(Address(0x0000000000000007))
access(all) let player1 = Test.createAccount()

access(all) fun setup() {
    // Deploy standard contracts in dependency order.
    // Paths are relative to this test file (cadence/tests/).
    // ../../../../ goes up to flow-blockchain-studio/ root.
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

    // Deploy the contract under test.
    // ../contracts/ is relative to this test file.
    err = Test.deployContract(
        name: "ChessPiece",
        path: "../contracts/ChessPiece.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all) fun testSetupCollection() {
    let result = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/setup_chess_account.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: []
        )
    )
    Test.expect(result, Test.beSucceeded())
}

access(all) fun testTotalSupplyStartsAtZero() {
    let supply = Test.executeScript(
        "import ChessPiece from 0x0000000000000007\naccess(all) fun main(): UInt64 { return ChessPiece.totalSupply }",
        []
    )
    Test.expect(supply, Test.beSucceeded())
    let count = supply.returnValue! as! UInt64
    Test.assertEqual(count, 0 as UInt64)
}

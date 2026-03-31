import Test
import "ChessPiece"

access(all) let deployer = Test.getAccount(Address(0xf8d6e0586b0a20c7))
access(all) let player1 = Test.createAccount()

access(all) fun setup() {
    let err = Test.deployContract(
        name: "ChessPiece",
        path: "../contracts/ChessPiece.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all) fun testSetupCollection() {
    let result = Test.executeTransaction(
        "../transactions/setup_chess_account.cdc",
        [],
        player1
    )
    Test.expect(result, Test.beSucceeded())
}

access(all) fun testTotalSupplyStartsAtZero() {
    let supply = Test.executeScript(
        "import ChessPiece from \"ChessPiece\"\naccess(all) fun main(): UInt64 { return ChessPiece.totalSupply }",
        []
    )
    Test.expect(supply, Test.beSucceeded())
    let count = supply.returnValue! as! UInt64
    Test.assertEqual(count, 0 as UInt64)
}

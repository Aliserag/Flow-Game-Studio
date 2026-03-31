import Test
import "ChessGame"
import "ChessPiece"

access(all) let deployer = Test.getAccount(Address(0xf8d6e0586b0a20c7))
access(all) let player1 = Test.createAccount()
access(all) let player2 = Test.createAccount()

access(all) fun setup() {
    Test.deployContract(name: "ChessPiece", path: "../contracts/ChessPiece.cdc", arguments: [])
    Test.deployContract(name: "ChessStatsAttachment", path: "../contracts/ChessStatsAttachment.cdc", arguments: [])
    Test.deployContract(name: "ChessGame", path: "../contracts/ChessGame.cdc", arguments: [])
    Test.executeTransaction("../transactions/setup_chess_account.cdc", [], player1)
    Test.executeTransaction("../transactions/setup_chess_account.cdc", [], player2)
}

access(all) fun testCreateChallenge() {
    let result = Test.executeTransaction(
        "../transactions/create_challenge.cdc",
        [player2.address],
        player1
    )
    Test.expect(result, Test.beSucceeded())
}

access(all) fun testAcceptChallenge() {
    let secret: UInt256 = 42
    let result = Test.executeTransaction(
        "../transactions/accept_challenge.cdc",
        [0 as UInt64, secret],
        player2
    )
    Test.expect(result, Test.beSucceeded())
}

access(all) fun testRevealColors() {
    let secret: UInt256 = 42
    let result = Test.executeTransaction(
        "../transactions/reveal_colors.cdc",
        [0 as UInt64, secret],
        player2
    )
    Test.expect(result, Test.beSucceeded())
}

access(all) fun testGetBoard() {
    let result = Test.executeScript("../scripts/get_board.cdc", [0 as UInt64])
    Test.expect(result, Test.beSucceeded())
    Test.assert(result.returnValue != nil, message: "Board data should not be nil")
}

access(all) fun testResign() {
    // Create a fresh game (gameId=1)
    Test.executeTransaction("../transactions/create_challenge.cdc", [player2.address], player1)
    Test.executeTransaction("../transactions/accept_challenge.cdc", [1 as UInt64, 99 as UInt256], player2)
    Test.executeTransaction("../transactions/reveal_colors.cdc", [1 as UInt64, 99 as UInt256], player2)

    // Get who is white and have them resign
    let boardResult = Test.executeScript("../scripts/get_board.cdc", [1 as UInt64])
    let boardData = boardResult.returnValue! as! {String: AnyStruct}
    let whiteAddr = boardData["white"] as! Address?
    let resigningPlayer = whiteAddr == player1.address ? player1 : player2

    let result = Test.executeTransaction("../transactions/resign_game.cdc", [1 as UInt64], resigningPlayer)
    Test.expect(result, Test.beSucceeded())
}

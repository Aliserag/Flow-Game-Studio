import Test
import "ChessGame"
import "ChessPiece"

access(all) let player1 = Test.createAccount()
access(all) let player2 = Test.createAccount()

access(all) fun setup() {
    // Note: standard contract setup duplicated from ChessPiece_test.cdc — Cadence testing has no shared fixtures
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

    // Required by MetadataViews transitive import (MetadataViews imports FungibleToken)
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

    err = Test.deployContract(
        name: "EmergencyPause",
        path: "../../../../cadence/contracts/systems/EmergencyPause.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "ChessPiece",
        path: "../contracts/ChessPiece.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "ChessStatsAttachment",
        path: "../contracts/ChessStatsAttachment.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "ChessGame",
        path: "../contracts/ChessGame.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Setup collections for both players
    Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/setup_chess_account.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: []
        )
    )
    Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/setup_chess_account.cdc"),
            authorizers: [player2.address],
            signers: [player2],
            arguments: []
        )
    )
}

access(all) fun testCreateChallenge() {
    let result = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/create_challenge.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: [player2.address]
        )
    )
    Test.expect(result, Test.beSucceeded())
}

access(all) fun testAcceptChallenge() {
    let secret: UInt256 = 42
    let result = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/accept_challenge.cdc"),
            authorizers: [player2.address],
            signers: [player2],
            arguments: [0 as UInt64, secret]
        )
    )
    Test.expect(result, Test.beSucceeded())
}

access(all) fun testRevealColors() {
    let secret: UInt256 = 42
    let result = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/reveal_colors.cdc"),
            authorizers: [player2.address],
            signers: [player2],
            arguments: [0 as UInt64, secret]
        )
    )
    Test.expect(result, Test.beSucceeded())
}

access(all) fun testGetBoard() {
    let result = Test.executeScript(
        Test.readFile("../scripts/get_board.cdc"),
        [0 as UInt64]
    )
    Test.expect(result, Test.beSucceeded())
    Test.assert(result.returnValue != nil, message: "Board data should not be nil")
}

access(all) fun testResign() {
    // Create a fresh game (gameId=1)
    let r1 = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/create_challenge.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: [player2.address]
        )
    )
    Test.expect(r1, Test.beSucceeded())
    let r2 = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/accept_challenge.cdc"),
            authorizers: [player2.address],
            signers: [player2],
            arguments: [1 as UInt64, 99 as UInt256]
        )
    )
    Test.expect(r2, Test.beSucceeded())
    let r3 = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/reveal_colors.cdc"),
            authorizers: [player2.address],
            signers: [player2],
            arguments: [1 as UInt64, 99 as UInt256]
        )
    )
    Test.expect(r3, Test.beSucceeded())

    // Get who is white and have them resign
    let boardResult = Test.executeScript(
        Test.readFile("../scripts/get_board.cdc"),
        [1 as UInt64]
    )
    Test.expect(boardResult, Test.beSucceeded())
    let boardData = boardResult.returnValue! as! {String: AnyStruct}
    let whiteAddr = boardData["white"]! as! Address
    let resigningPlayer = whiteAddr == player1.address ? player1 : player2

    let result = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/resign_game.cdc"),
            authorizers: [resigningPlayer.address],
            signers: [resigningPlayer],
            arguments: [1 as UInt64]
        )
    )
    Test.expect(result, Test.beSucceeded())
}

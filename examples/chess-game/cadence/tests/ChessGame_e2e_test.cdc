import Test

access(all) let player1 = Test.createAccount()
access(all) let player2 = Test.createAccount()

access(all) fun setup() {
    // Note: standard contract setup duplicated from ChessGame_test.cdc — Cadence testing has no shared fixtures

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
}

// Full end-to-end game lifecycle: setup → challenge → accept → reveal → moves → resign
access(all) fun testFullGameLifecycle() {
    // ── Step 1: Setup collections for both players ──────────────────────────
    let setupResult1 = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/setup_chess_account.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: []
        )
    )
    Test.expect(setupResult1, Test.beSucceeded())

    let setupResult2 = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/setup_chess_account.cdc"),
            authorizers: [player2.address],
            signers: [player2],
            arguments: []
        )
    )
    Test.expect(setupResult2, Test.beSucceeded())

    // ── Step 2: Query the gameId that will be assigned BEFORE creating the challenge ──
    // When multiple test files share blockchain state, nextGameId may be > 0
    let nextIdResult = Test.executeScript(
        Test.readFile("../scripts/get_next_game_id.cdc"),
        []
    )
    Test.expect(nextIdResult, Test.beSucceeded())
    Test.assert(nextIdResult.returnValue != nil, message: "nextGameId should not be nil")
    let gameId = nextIdResult.returnValue! as! UInt64

    // ── Step 3: player1 challenges player2 ──────────────────────────────────
    let challengeResult = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/create_challenge.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: [player2.address]
        )
    )
    Test.expect(challengeResult, Test.beSucceeded())

    // ── Step 4: player2 accepts with secret=42 ───────────────────────────────
    let secret: UInt256 = 42
    let acceptResult = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/accept_challenge.cdc"),
            authorizers: [player2.address],
            signers: [player2],
            arguments: [gameId, secret]
        )
    )
    Test.expect(acceptResult, Test.beSucceeded())

    // ── Step 5: player2 reveals colors with same secret ──────────────────────
    // secret=42 → 42 % 2 == 0 → challenger(player1)=white, opponent(player2)=black
    let revealResult = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/reveal_colors.cdc"),
            authorizers: [player2.address],
            signers: [player2],
            arguments: [gameId, secret]
        )
    )
    Test.expect(revealResult, Test.beSucceeded())

    // ── Step 6: Verify initial game state ────────────────────────────────────
    let boardResult = Test.executeScript(
        Test.readFile("../scripts/get_board.cdc"),
        [gameId]
    )
    Test.expect(boardResult, Test.beSucceeded())
    Test.assert(boardResult.returnValue != nil, message: "Board data should not be nil")
    let boardData = boardResult.returnValue! as! {String: AnyStruct}

    // Status should be active (rawValue=1)
    Test.assert(boardData["status"] != nil, message: "status key missing from board data")
    let status = boardData["status"]! as! UInt8
    Test.assertEqual(status, 1 as UInt8)  // 1 = GameStatus.active

    // Colors: secret=42, 42%2==0 → player1=white, player2=black
    Test.assert(boardData["white"] != nil, message: "white key missing from board data")
    Test.assert(boardData["black"] != nil, message: "black key missing from board data")
    let whiteAddr = boardData["white"]! as! Address
    let blackAddr = boardData["black"]! as! Address
    Test.assertEqual(whiteAddr, player1.address)
    Test.assertEqual(blackAddr, player2.address)

    // FEN should be the starting position
    Test.assert(boardData["fen"] != nil, message: "fen key missing from board data")
    let initialFen = boardData["fen"]! as! String
    Test.assertEqual(initialFen, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    // ── Step 7: Verify 16 pieces minted per player ───────────────────────────
    // get_piece_collection returns [UInt64] (array of NFT IDs)
    let p1CollectionResult = Test.executeScript(
        Test.readFile("../scripts/get_piece_collection.cdc"),
        [player1.address]
    )
    Test.expect(p1CollectionResult, Test.beSucceeded())
    Test.assert(p1CollectionResult.returnValue != nil, message: "player1 collection should not be nil")
    let p1Ids = p1CollectionResult.returnValue! as! [UInt64]
    Test.assertEqual(p1Ids.length, 16)

    let p2CollectionResult = Test.executeScript(
        Test.readFile("../scripts/get_piece_collection.cdc"),
        [player2.address]
    )
    Test.expect(p2CollectionResult, Test.beSucceeded())
    Test.assert(p2CollectionResult.returnValue != nil, message: "player2 collection should not be nil")
    let p2Ids = p2CollectionResult.returnValue! as! [UInt64]
    Test.assertEqual(p2Ids.length, 16)

    // ── Step 8: Make move 1 — White e2e4 ─────────────────────────────────────
    // Starting FEN has " w " → white's turn → player1 moves
    let fenAfterMove1 = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
    let move1Result = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/make_move.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: [gameId, "e2e4", fenAfterMove1, false, false]
        )
    )
    Test.expect(move1Result, Test.beSucceeded())

    // Verify FEN changed after move 1
    let boardAfterMove1 = Test.executeScript(
        Test.readFile("../scripts/get_board.cdc"),
        [gameId]
    )
    Test.expect(boardAfterMove1, Test.beSucceeded())
    Test.assert(boardAfterMove1.returnValue != nil, message: "Board data after move 1 should not be nil")
    let boardData1 = boardAfterMove1.returnValue! as! {String: AnyStruct}
    Test.assert(boardData1["fen"] != nil, message: "fen key missing from board data after move 1")
    let fenAfter1 = boardData1["fen"]! as! String
    Test.assertEqual(fenAfter1, fenAfterMove1)

    // Verify move history has 1 entry
    let historyAfter1 = Test.executeScript(
        Test.readFile("../scripts/get_move_history.cdc"),
        [gameId]
    )
    Test.expect(historyAfter1, Test.beSucceeded())
    Test.assert(historyAfter1.returnValue != nil, message: "Move history after move 1 should not be nil")
    let moves1 = historyAfter1.returnValue! as! [String]
    Test.assertEqual(moves1.length, 1)
    Test.assertEqual(moves1[0], "e2e4")

    // ── Step 9: Make move 2 — Black e7e5 ─────────────────────────────────────
    // fenAfterMove1 has " b " → black's turn → player2 moves
    let fenAfterMove2 = "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2"
    let move2Result = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/make_move.cdc"),
            authorizers: [player2.address],
            signers: [player2],
            arguments: [gameId, "e7e5", fenAfterMove2, false, false]
        )
    )
    Test.expect(move2Result, Test.beSucceeded())

    // Verify FEN changed after move 2
    let boardAfterMove2 = Test.executeScript(
        Test.readFile("../scripts/get_board.cdc"),
        [gameId]
    )
    Test.expect(boardAfterMove2, Test.beSucceeded())
    Test.assert(boardAfterMove2.returnValue != nil, message: "Board data after move 2 should not be nil")
    let boardData2 = boardAfterMove2.returnValue! as! {String: AnyStruct}
    Test.assert(boardData2["fen"] != nil, message: "fen key missing from board data after move 2")
    let fenAfter2 = boardData2["fen"]! as! String
    Test.assertEqual(fenAfter2, fenAfterMove2)

    // Verify move history has 2 entries
    let historyAfter2 = Test.executeScript(
        Test.readFile("../scripts/get_move_history.cdc"),
        [gameId]
    )
    Test.expect(historyAfter2, Test.beSucceeded())
    Test.assert(historyAfter2.returnValue != nil, message: "Move history after move 2 should not be nil")
    let moves2 = historyAfter2.returnValue! as! [String]
    Test.assertEqual(moves2.length, 2)
    Test.assertEqual(moves2[1], "e7e5")

    // ── Step 10: Make move 3 — White d1h5 (Scholar's attack) ──────────────────
    // fenAfterMove2 has " w " → white's turn → player1 moves
    let fenAfterMove3 = "rnbqkbnr/pppp1ppp/8/4p2Q/4P3/8/PPPP1PPP/RNB1KBNR b KQkq - 1 2"
    let move3Result = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/make_move.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: [gameId, "d1h5", fenAfterMove3, false, false]
        )
    )
    Test.expect(move3Result, Test.beSucceeded())

    // Verify FEN changed after move 3
    let boardAfterMove3 = Test.executeScript(
        Test.readFile("../scripts/get_board.cdc"),
        [gameId]
    )
    Test.expect(boardAfterMove3, Test.beSucceeded())
    Test.assert(boardAfterMove3.returnValue != nil, message: "Board data after move 3 should not be nil")
    let boardData3 = boardAfterMove3.returnValue! as! {String: AnyStruct}
    Test.assert(boardData3["fen"] != nil, message: "fen key missing from board data after move 3")
    let fenAfter3 = boardData3["fen"]! as! String
    Test.assertEqual(fenAfter3, fenAfterMove3)

    // Verify full move history after 3 moves
    let historyAfter3 = Test.executeScript(
        Test.readFile("../scripts/get_move_history.cdc"),
        [gameId]
    )
    Test.expect(historyAfter3, Test.beSucceeded())
    Test.assert(historyAfter3.returnValue != nil, message: "Move history after move 3 should not be nil")
    let moves3 = historyAfter3.returnValue! as! [String]
    Test.assertEqual(moves3.length, 3)
    Test.assertEqual(moves3[0], "e2e4")
    Test.assertEqual(moves3[1], "e7e5")
    Test.assertEqual(moves3[2], "d1h5")

    // ── Step 11: White (player1) resigns ─────────────────────────────────────
    let resignResult = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/resign_game.cdc"),
            authorizers: [player1.address],
            signers: [player1],
            arguments: [gameId]
        )
    )
    Test.expect(resignResult, Test.beSucceeded())

    // ── Step 12: Verify final game state ─────────────────────────────────────
    let finalBoardResult = Test.executeScript(
        Test.readFile("../scripts/get_board.cdc"),
        [gameId]
    )
    Test.expect(finalBoardResult, Test.beSucceeded())
    Test.assert(finalBoardResult.returnValue != nil, message: "Final board data should not be nil")
    let finalBoardData = finalBoardResult.returnValue! as! {String: AnyStruct}

    // Status should be resigned (rawValue=4)
    Test.assert(finalBoardData["status"] != nil, message: "status key missing from final board data")
    let finalStatus = finalBoardData["status"]! as! UInt8
    Test.assertEqual(finalStatus, 4 as UInt8)  // 4 = GameStatus.resigned

    // Winner should be black (player2) — the non-resigning player
    // In the contract: resign sets winner = caller == challenger ? opponent : challenger
    // player1 is challenger, so winner = opponent = player2
    Test.assert(finalBoardData["winner"] != nil, message: "winner key missing from final board data")
    let winnerAddr = finalBoardData["winner"]! as! Address
    Test.assertEqual(winnerAddr, player2.address)
}

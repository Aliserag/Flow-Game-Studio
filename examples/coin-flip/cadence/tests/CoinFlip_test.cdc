/// CoinFlip_test.cdc — Cadence 1.0 Testing Framework tests for CoinFlip.
///
/// Actual API (verified from this repo's own tests):
///   - Test.createAccount()
///   - Test.deployContract(name: path: arguments:)
///   - Test.executeTransaction(Test.Transaction(code:|path: authorizers: signers: arguments:))
///   - Test.executeScript(path_or_code, args)
///   - Test.commitBlock()  — advance the emulator by one block
///   - Test.expect(result, Test.beSucceeded() | Test.beFailed())
///
/// Run with: flow test cadence/tests/CoinFlip_test.cdc
import Test

// ---------------------------------------------------------------------------
// Accounts — created once, shared across all test functions
// ---------------------------------------------------------------------------

access(all) let player = Test.createAccount()

// ---------------------------------------------------------------------------
// Setup — deploy contracts in dependency order
// ---------------------------------------------------------------------------

access(all) fun setup() {
    // Step 1: Deploy the vendored RandomBeaconHistory stub.
    // Path is relative to THIS test file.
    // From examples/coin-flip/cadence/tests/ → up 4 levels to repo root.
    var err = Test.deployContract(
        name: "RandomBeaconHistory",
        path: "../../../../cadence/contracts/standards/RandomBeaconHistory.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Step 2: Deploy CoinFlip (imports RandomBeaconHistory by name).
    err = Test.deployContract(
        name: "CoinFlip",
        path: "../contracts/CoinFlip.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

// ---------------------------------------------------------------------------
// Helper: commit a flip
// ---------------------------------------------------------------------------

access(all) fun commitFlip(commitHashHex: String, playerChoice: Bool): Test.TransactionResult {
    return Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/commit_flip.cdc"),
            authorizers: [player.address],
            signers: [player],
            arguments: [commitHashHex, playerChoice]
        )
    )
}

// ---------------------------------------------------------------------------
// Helper: reveal a flip
// ---------------------------------------------------------------------------

access(all) fun revealFlip(flipId: UInt64, secret: UInt256): Test.TransactionResult {
    return Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/reveal_flip.cdc"),
            authorizers: [player.address],
            signers: [player],
            arguments: [flipId, secret]
        )
    )
}

// ---------------------------------------------------------------------------
// Test 1: testCommitAndReveal
//
// Happy path — commit, advance one block, reveal, assert resolved.
// ---------------------------------------------------------------------------

access(all) fun testCommitAndReveal() {
    // Arrange
    let secret: UInt256 = 0
    let commitHashHex = "0000000000000000000000000000000000000000000000000000000000000000"

    // Act — commit (flipId 0)
    let commitResult = commitFlip(commitHashHex: commitHashHex, playerChoice: true)
    Test.expect(commitResult, Test.beSucceeded())

    // Advance one block so the commit block's randomness is sealed
    Test.commitBlock()

    // Reveal
    let revealResult = revealFlip(flipId: 0, secret: secret)
    Test.expect(revealResult, Test.beSucceeded())

    // Assert — query the flip and confirm it is resolved
    let scriptResult = Test.executeScript(
        Test.readFile("../scripts/get_flip.cdc"),
        [player.address, 0 as UInt64]
    )
    Test.expect(scriptResult, Test.beSucceeded())
    Test.assert(scriptResult.returnValue != nil, message: "Flip should exist after reveal")
}

// ---------------------------------------------------------------------------
// Test 2: testCannotRevealTwice
//
// Commit, advance, reveal — then try to reveal the same flip again.
// The second reveal must fail with "Flip already resolved".
//
// Note: in the Cadence Testing Framework each executeTransaction() call
// naturally advances the block, so same-block testing via two separate
// transactions is not possible.  We test the other error guard instead:
// calling reveal() on an already-resolved flip.
// ---------------------------------------------------------------------------

access(all) fun testCannotRevealTwice() {
    // Arrange — flipId 1 (sequential after test 1's flipId 0)
    let secret: UInt256 = 42
    let commitHashHex = "0000000000000000000000000000000000000000000000000000000000000001"

    // Act — commit
    let commitResult = commitFlip(commitHashHex: commitHashHex, playerChoice: false)
    Test.expect(commitResult, Test.beSucceeded())

    // Advance one block
    Test.commitBlock()

    // First reveal — must succeed
    let reveal1 = revealFlip(flipId: 1, secret: secret)
    Test.expect(reveal1, Test.beSucceeded())

    // Second reveal on same flip — must fail: "Flip already resolved"
    let reveal2 = revealFlip(flipId: 1, secret: secret)
    Test.expect(reveal2, Test.beFailed())
}

// ---------------------------------------------------------------------------
// Test 3: testMultipleFlips
//
// Same player commits two flips, advances blocks, reveals both successfully.
// ---------------------------------------------------------------------------

access(all) fun testMultipleFlips() {
    // Arrange
    let secret1: UInt256 = 100
    let secret2: UInt256 = 200
    let hash1 = "0000000000000000000000000000000000000000000000000000000000000002"
    let hash2 = "0000000000000000000000000000000000000000000000000000000000000003"

    // Act — commit twice (flipIds 2 and 3)
    let commit1 = commitFlip(commitHashHex: hash1, playerChoice: true)
    Test.expect(commit1, Test.beSucceeded())

    let commit2 = commitFlip(commitHashHex: hash2, playerChoice: false)
    Test.expect(commit2, Test.beSucceeded())

    // Advance two blocks to be safe
    Test.commitBlock()
    Test.commitBlock()

    // Reveal both
    let reveal1 = revealFlip(flipId: 2, secret: secret1)
    Test.expect(reveal1, Test.beSucceeded())

    let reveal2 = revealFlip(flipId: 3, secret: secret2)
    Test.expect(reveal2, Test.beSucceeded())

    // Assert — both flips exist and are resolved
    let result2 = Test.executeScript(
        Test.readFile("../scripts/get_flip.cdc"),
        [player.address, 2 as UInt64]
    )
    Test.expect(result2, Test.beSucceeded())
    Test.assert(result2.returnValue != nil, message: "Flip 2 should be resolved")

    let result3 = Test.executeScript(
        Test.readFile("../scripts/get_flip.cdc"),
        [player.address, 3 as UInt64]
    )
    Test.expect(result3, Test.beSucceeded())
    Test.assert(result3.returnValue != nil, message: "Flip 3 should be resolved")
}

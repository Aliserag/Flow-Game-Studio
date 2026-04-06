// cadence/tests/Tournament_test.cdc
//
// Tests for the Tournament contract.
// Deploys GameToken, RandomVRF, Scheduler, and Tournament in sequence,
// then exercises create, join, start, resolve, and claim flows.
//
// API notes (Flow CLI v2.x):
//   - Test.deployContract() deploys to 0x0000000000000007 in the test env.
//   - Test.Transaction struct required for executeTransaction.
//   - Test.readFile() loads file content from a path.
//   - Contract state accessed via `import` is a snapshot at compile time.
//     Use executeScript to read live on-chain state.
import Test
import "Tournament"

// Deployer account — 0x0000000000000007 in the test environment
access(all) let deployer = Test.getAccount(0x0000000000000007)

// -------------------------------------------------------------------------
// setup() — deploys all required contracts ONCE before all tests
// -------------------------------------------------------------------------

access(all) fun setup() {
    // 1. Deploy GameToken (required by Tournament for prize vaults)
    let tokenErr = Test.deployContract(
        name: "GameToken",
        path: "../contracts/core/GameToken.cdc",
        arguments: ["Gold", "GOLD", UFix64(1_000_000_000.0)]
    )
    Test.expect(tokenErr, Test.beNil())

    // 2. Deploy RandomVRF (required by Tournament for bracket seeding)
    let vrfErr = Test.deployContract(
        name: "RandomVRF",
        path: "../contracts/systems/RandomVRF.cdc",
        arguments: []
    )
    Test.expect(vrfErr, Test.beNil())

    // 3. Deploy Scheduler (required by Tournament for epoch duration checks)
    let schedulerErr = Test.deployContract(
        name: "Scheduler",
        path: "../contracts/systems/Scheduler.cdc",
        arguments: []
    )
    Test.expect(schedulerErr, Test.beNil())

    // 4. Deploy Tournament (depends on all of the above)
    let tournamentErr = Test.deployContract(
        name: "Tournament",
        path: "../contracts/systems/Tournament.cdc",
        arguments: []
    )
    Test.expect(tournamentErr, Test.beNil())
}

// -------------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------------

/// Execute a file-based transaction signed by `signer`.
access(all) fun runTx(_ path: String, _ args: [AnyStruct], _ signer: Test.TestAccount): Test.TransactionResult {
    let tx = Test.Transaction(
        code: Test.readFile(path),
        authorizers: [signer.address],
        signers: [signer],
        arguments: args
    )
    return Test.executeTransaction(tx)
}

/// Set up a player account with a token vault.
access(all) fun setupPlayer(_ player: Test.TestAccount) {
    Test.expect(
        runTx("../transactions/token/setup_token_vault.cdc", [], player),
        Test.beSucceeded()
    )
}

/// Mint GameTokens to a player. Signed by deployer (Minter owner).
access(all) fun mintTokens(_ recipient: Address, _ amount: UFix64) {
    let tx = Test.Transaction(
        code: Test.readFile("../transactions/token/mint_tokens.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [recipient, amount]
    )
    Test.expect(Test.executeTransaction(tx), Test.beSucceeded())
}

/// Query tournament total count via script (live chain state).
access(all) fun getTotalTournaments(): UInt64 {
    let script = "import \"Tournament\"\naccess(all) fun main(): UInt64 { return Tournament.totalTournaments }"
    let result = Test.executeScript(script, [])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UInt64
}

/// Query tournament status via script.
access(all) fun getTournamentStatus(_ id: UInt64): UInt8 {
    let script = "import \"Tournament\"\naccess(all) fun main(id: UInt64): UInt8 { return Tournament.getTournament(id)!.status.rawValue }"
    let result = Test.executeScript(script, [id])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UInt8
}

/// Query prize pool for a tournament via script.
access(all) fun getPrizePool(_ id: UInt64): UFix64 {
    let script = "import \"Tournament\"\naccess(all) fun main(id: UInt64): UFix64 { return Tournament.getTournament(id)!.prizePool }"
    let result = Test.executeScript(script, [id])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UFix64
}

/// Query number of players in a tournament via script.
access(all) fun getPlayerCount(_ id: UInt64): Int {
    let script = "import \"Tournament\"\naccess(all) fun main(id: UInt64): Int { return Tournament.getTournament(id)!.players.length }"
    let result = Test.executeScript(script, [id])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! Int
}

/// Query token balance for an address.
access(all) fun getBalance(_ address: Address): UFix64 {
    let result = Test.executeScript(
        Test.readFile("../scripts/get_token_balance.cdc"),
        [address]
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UFix64
}

// Status raw values (must match TournamentStatus enum)
access(all) let STATUS_REGISTRATION: UInt8 = 0
access(all) let STATUS_ACTIVE: UInt8       = 1
access(all) let STATUS_RESOLVED: UInt8     = 2
access(all) let STATUS_CANCELLED: UInt8    = 3

// Shared VRF secret used across start/resolve tests
access(all) let VRF_SECRET: UInt256 = 99999

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

/// Tournament contract deploys with zero tournaments.
access(all) fun testDeployment() {
    // Assert
    Test.assertEqual(getTotalTournaments(), UInt64(0))
}

/// Anyone can create a tournament; totalTournaments increments.
access(all) fun testCreateTournament() {
    // Arrange — use the deployer as the creator
    let beforeCount = getTotalTournaments()

    // Act
    let result = runTx(
        "../transactions/tournament/create_tournament.cdc",
        ["Dragon Cup", UInt32(8), UFix64(10.0), UInt64(1)],
        deployer
    )
    Test.expect(result, Test.beSucceeded())

    // Assert
    Test.assertEqual(getTotalTournaments(), beforeCount + UInt64(1))
    Test.assertEqual(getTournamentStatus(beforeCount), STATUS_REGISTRATION)
    Test.assertEqual(getPrizePool(beforeCount), UFix64(0.0))
}

/// A player with sufficient tokens can join a tournament.
access(all) fun testJoinTournament() {
    // Arrange — create a fresh tournament and fund a new player
    let tournamentId = getTotalTournaments()
    let createResult = runTx(
        "../transactions/tournament/create_tournament.cdc",
        ["Silver Cup", UInt32(4), UFix64(10.0), UInt64(1)],
        deployer
    )
    Test.expect(createResult, Test.beSucceeded())

    let player = Test.createAccount()
    setupPlayer(player)
    mintTokens(player.address, UFix64(50.0))

    // Act
    let joinResult = runTx(
        "../transactions/tournament/join_tournament.cdc",
        [tournamentId],
        player
    )
    Test.expect(joinResult, Test.beSucceeded())

    // Assert
    Test.assertEqual(getPlayerCount(tournamentId), 1)
    Test.assertEqual(getPrizePool(tournamentId), UFix64(10.0))
    // Player's balance decreased by the entry fee
    Test.assertEqual(getBalance(player.address), UFix64(40.0))
}

/// A player cannot join twice.
access(all) fun testJoinTournamentDuplicateFails() {
    // Arrange
    let tournamentId = getTotalTournaments()
    let createResult = runTx(
        "../transactions/tournament/create_tournament.cdc",
        ["Bronze Cup", UInt32(4), UFix64(5.0), UInt64(1)],
        deployer
    )
    Test.expect(createResult, Test.beSucceeded())

    let player = Test.createAccount()
    setupPlayer(player)
    mintTokens(player.address, UFix64(100.0))

    // First join — should succeed
    Test.expect(
        runTx("../transactions/tournament/join_tournament.cdc", [tournamentId], player),
        Test.beSucceeded()
    )

    // Act — second join attempt
    let secondJoin = Test.Transaction(
        code: Test.readFile("../transactions/tournament/join_tournament.cdc"),
        authorizers: [player.address],
        signers: [player],
        arguments: [tournamentId]
    )
    let result = Test.executeTransaction(secondJoin)

    // Assert — must fail
    Test.expect(result, Test.beFailed())
}

/// A tournament cannot be resolved before its duration elapses.
access(all) fun testResolveTournamentBeforeDurationFails() {
    // Arrange — create tournament with durationEpochs = 100 (very long)
    let tournamentId = getTotalTournaments()
    let createResult = runTx(
        "../transactions/tournament/create_tournament.cdc",
        ["Long Cup", UInt32(4), UFix64(5.0), UInt64(100)],
        deployer
    )
    Test.expect(createResult, Test.beSucceeded())

    // Add 2 players
    let playerA = Test.createAccount()
    let playerB = Test.createAccount()
    setupPlayer(playerA)
    setupPlayer(playerB)
    mintTokens(playerA.address, UFix64(50.0))
    mintTokens(playerB.address, UFix64(50.0))

    Test.expect(
        runTx("../transactions/tournament/join_tournament.cdc", [tournamentId], playerA),
        Test.beSucceeded()
    )
    Test.expect(
        runTx("../transactions/tournament/join_tournament.cdc", [tournamentId], playerB),
        Test.beSucceeded()
    )

    // Start the tournament
    Test.expect(
        runTx("../transactions/tournament/start_tournament.cdc", [tournamentId, VRF_SECRET], deployer),
        Test.beSucceeded()
    )
    Test.assertEqual(getTournamentStatus(tournamentId), STATUS_ACTIVE)

    // Commit at least 1 block so VRF reveal is allowed, but don't advance epoch
    Test.commitBlock()

    // Act — try to resolve immediately (epoch 0, needs epoch >= 100)
    let resolveTx = Test.Transaction(
        code: Test.readFile("../transactions/tournament/resolve_tournament.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [tournamentId, [playerA.address, playerB.address], VRF_SECRET]
    )
    let resolveResult = Test.executeTransaction(resolveTx)

    // Assert — must fail (duration not elapsed)
    Test.expect(resolveResult, Test.beFailed())
}

/// Full happy path: create, join (3 players), start, advance epoch, resolve, claim prizes.
access(all) fun testTournamentFullLifecycle() {
    // Arrange
    let tournamentId = getTotalTournaments()
    let createResult = runTx(
        "../transactions/tournament/create_tournament.cdc",
        ["Grand Cup", UInt32(8), UFix64(100.0), UInt64(1)],
        deployer
    )
    Test.expect(createResult, Test.beSucceeded())

    let player1 = Test.createAccount()
    let player2 = Test.createAccount()
    let player3 = Test.createAccount()
    setupPlayer(player1)
    setupPlayer(player2)
    setupPlayer(player3)
    mintTokens(player1.address, UFix64(200.0))
    mintTokens(player2.address, UFix64(200.0))
    mintTokens(player3.address, UFix64(200.0))

    // All three join (prize pool = 300)
    Test.expect(
        runTx("../transactions/tournament/join_tournament.cdc", [tournamentId], player1),
        Test.beSucceeded()
    )
    Test.expect(
        runTx("../transactions/tournament/join_tournament.cdc", [tournamentId], player2),
        Test.beSucceeded()
    )
    Test.expect(
        runTx("../transactions/tournament/join_tournament.cdc", [tournamentId], player3),
        Test.beSucceeded()
    )
    Test.assertEqual(getPrizePool(tournamentId), UFix64(300.0))

    // Start the tournament — commits VRF
    Test.expect(
        runTx("../transactions/tournament/start_tournament.cdc", [tournamentId, VRF_SECRET], deployer),
        Test.beSucceeded()
    )
    Test.assertEqual(getTournamentStatus(tournamentId), STATUS_ACTIVE)

    // Advance 1001 blocks so the epoch can advance (epochBlockLength = 1000)
    var i = 0
    while i < 1001 {
        Test.commitBlock()
        i = i + 1
    }

    // Advance the epoch (calls Scheduler.processEpoch())
    // process_epoch.cdc has no prepare block — use empty authorizers/signers
    let epochTx = Test.Transaction(
        code: Test.readFile("../transactions/scheduler/process_epoch.cdc"),
        authorizers: [],
        signers: [],
        arguments: []
    )
    Test.expect(Test.executeTransaction(epochTx), Test.beSucceeded())

    // Act — resolve tournament (player1 = 1st, player2 = 2nd, player3 = 3rd)
    let resolveResult = runTx(
        "../transactions/tournament/resolve_tournament.cdc",
        [tournamentId, [player1.address, player2.address, player3.address], VRF_SECRET],
        deployer
    )
    Test.expect(resolveResult, Test.beSucceeded())
    Test.assertEqual(getTournamentStatus(tournamentId), STATUS_RESOLVED)

    // Assert prize allocation via claimPrize
    // Prize pool = 300. Shares: 1st=60%(180), 2nd=30%(90), 3rd=10%(30)
    let p1BalanceBefore = getBalance(player1.address)
    let claimTx1 = Test.Transaction(
        code: "import \"Tournament\"\ntransaction(id: UInt64, player: Address) { prepare(s: auth(Storage) &Account) {} execute { Tournament.claimPrize(tournamentId: id, player: player) } }",
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [tournamentId, player1.address]
    )
    Test.expect(Test.executeTransaction(claimTx1), Test.beSucceeded())
    let p1BalanceAfter = getBalance(player1.address)
    // 1st place receives 180 tokens (300 - 90 - 30 = 180)
    Test.assertEqual(p1BalanceAfter - p1BalanceBefore, UFix64(180.0))

    let p2BalanceBefore = getBalance(player2.address)
    let claimTx2 = Test.Transaction(
        code: "import \"Tournament\"\ntransaction(id: UInt64, player: Address) { prepare(s: auth(Storage) &Account) {} execute { Tournament.claimPrize(tournamentId: id, player: player) } }",
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [tournamentId, player2.address]
    )
    Test.expect(Test.executeTransaction(claimTx2), Test.beSucceeded())
    let p2BalanceAfter = getBalance(player2.address)
    // 2nd place receives 90 tokens (300 * 0.3)
    Test.assertEqual(p2BalanceAfter - p2BalanceBefore, UFix64(90.0))

    let p3BalanceBefore = getBalance(player3.address)
    let claimTx3 = Test.Transaction(
        code: "import \"Tournament\"\ntransaction(id: UInt64, player: Address) { prepare(s: auth(Storage) &Account) {} execute { Tournament.claimPrize(tournamentId: id, player: player) } }",
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [tournamentId, player3.address]
    )
    Test.expect(Test.executeTransaction(claimTx3), Test.beSucceeded())
    let p3BalanceAfter = getBalance(player3.address)
    // 3rd place receives 30 tokens (300 * 0.1)
    Test.assertEqual(p3BalanceAfter - p3BalanceBefore, UFix64(30.0))
}

/// Double-claim must fail.
access(all) fun testDoubleClaimFails() {
    // We'll reuse the most recently resolved tournament from the lifecycle test.
    // Find the last resolved tournament id (totalTournaments - 1).
    let tournamentId = getTotalTournaments() - UInt64(1)

    // player1 already claimed; trying again should fail
    let claimTx = Test.Transaction(
        code: "import \"Tournament\"\ntransaction(id: UInt64, player: Address) { prepare(s: auth(Storage) &Account) {} execute { Tournament.claimPrize(tournamentId: id, player: player) } }",
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [tournamentId, Test.getAccount(0x0000000000000007).address]
    )
    // This should panic (prize is 0.0 after first claim)
    Test.expect(Test.executeTransaction(claimTx), Test.beFailed())
}

/// Creating a tournament with 0 duration should fail.
access(all) fun testCreateTournamentZeroDurationFails() {
    let tx = Test.Transaction(
        code: Test.readFile("../transactions/tournament/create_tournament.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: ["Bad Cup", UInt32(4), UFix64(10.0), UInt64(0)]
    )
    Test.expect(Test.executeTransaction(tx), Test.beFailed())
}

/// Creating a tournament with only 1 max player should fail.
access(all) fun testCreateTournamentTooFewPlayersFails() {
    let tx = Test.Transaction(
        code: Test.readFile("../transactions/tournament/create_tournament.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: ["Solo Cup", UInt32(1), UFix64(10.0), UInt64(1)]
    )
    Test.expect(Test.executeTransaction(tx), Test.beFailed())
}

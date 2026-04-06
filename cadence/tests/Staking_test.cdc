// cadence/tests/Staking_test.cdc
//
// Tests for the Staking contract.
//
// Covers:
//   - testStake: stake works, position created with correct fields
//   - testEarlyUnstakeFails: unstake before lock expires panics
//   - testUnstakeAfterLock: advance blocks, unstake succeeds, principal returned
//   - testYieldCalculation: stake, advance blocks, claimYield, check balance

import Test
import "Staking"

// Deployer account — 0x0000000000000007 in the test environment
access(all) let deployer = Test.getAccount(0x0000000000000007)

// -------------------------------------------------------------------------
// setup() — deploys GameToken then Staking before all tests
// -------------------------------------------------------------------------

access(all) fun setup() {
    // 1. Deploy GameToken (required by Staking for vault types and receivers)
    let tokenErr = Test.deployContract(
        name: "GameToken",
        path: "../contracts/core/GameToken.cdc",
        arguments: ["Gold", "GOLD", UFix64(1_000_000_000.0)]
    )
    Test.expect(tokenErr, Test.beNil())

    // 2. Deploy Staking
    let stakingErr = Test.deployContract(
        name: "Staking",
        path: "../contracts/systems/Staking.cdc",
        arguments: []
    )
    Test.expect(stakingErr, Test.beNil())
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

/// Set up a GameToken vault for an account.
access(all) fun setupTokenVault(_ account: Test.TestAccount) {
    Test.expect(
        runTx("../transactions/token/setup_token_vault.cdc", [], account),
        Test.beSucceeded()
    )
}

/// Mint GameTokens to a recipient. Signed by deployer (Minter owner).
access(all) fun mintTokens(_ recipient: Address, _ amount: UFix64) {
    let tx = Test.Transaction(
        code: Test.readFile("../transactions/token/mint_tokens.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [recipient, amount]
    )
    Test.expect(Test.executeTransaction(tx), Test.beSucceeded())
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

/// Query total positions via script.
access(all) fun getTotalPositions(): UInt64 {
    let result = Test.executeScript(
        "import \"Staking\"\naccess(all) fun main(): UInt64 { return Staking.totalPositions }",
        []
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UInt64
}

/// Query stake vault balance via script.
access(all) fun getStakeVaultBalance(): UFix64 {
    let result = Test.executeScript(
        "import \"Staking\"\naccess(all) fun main(): UFix64 { return Staking.stakeVaultBalance() }",
        []
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UFix64
}

/// Query yield pool balance via script.
access(all) fun getYieldPoolBalance(): UFix64 {
    let result = Test.executeScript(
        "import \"Staking\"\naccess(all) fun main(): UFix64 { return Staking.yieldPoolBalance() }",
        []
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UFix64
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

/// Staking contract deploys with zero positions and default yield rate.
access(all) fun testDeployment() {
    // Assert
    Test.assertEqual(getTotalPositions(), UInt64(0))
    Test.assertEqual(getStakeVaultBalance(), UFix64(0.0))
}

/// Player can stake tokens; position is created and tokens are escrowed.
access(all) fun testStake() {
    // Arrange
    let player = Test.createAccount()
    setupTokenVault(player)
    mintTokens(player.address, UFix64(100.0))

    let beforeVaultBalance = getStakeVaultBalance()
    let beforePositions    = getTotalPositions()

    // Act — stake 50 tokens with a 10-block lock
    let stakeResult = runTx(
        "../transactions/staking/stake_position.cdc",
        [UFix64(50.0), UInt64(10)],
        player
    )
    Test.expect(stakeResult, Test.beSucceeded())

    // Assert — position created and tokens escrowed
    Test.assertEqual(getTotalPositions(), beforePositions + UInt64(1))
    Test.assertEqual(getStakeVaultBalance(), beforeVaultBalance + UFix64(50.0))
    // Player's wallet decreased by staked amount
    Test.assertEqual(getBalance(player.address), UFix64(50.0))
}

/// Unstaking before lock period expires should fail.
access(all) fun testEarlyUnstakeFails() {
    // Arrange — stake with a 10000-block lock (very long)
    let player = Test.createAccount()
    setupTokenVault(player)
    mintTokens(player.address, UFix64(100.0))

    let positionId = getTotalPositions()
    Test.expect(
        runTx("../transactions/staking/stake_position.cdc", [UFix64(100.0), UInt64(10000)], player),
        Test.beSucceeded()
    )

    // Act — try to unstake immediately (lock not elapsed)
    let unstakeTx = Test.Transaction(
        code: Test.readFile("../transactions/staking/unstake_position.cdc"),
        authorizers: [player.address],
        signers: [player],
        arguments: [positionId]
    )
    let result = Test.executeTransaction(unstakeTx)

    // Assert — must fail
    Test.expect(result, Test.beFailed())
}

/// After lock period elapses, unstake succeeds and principal is returned.
access(all) fun testUnstakeAfterLock() {
    // Arrange — stake with a 2-block lock (short for testing)
    let player = Test.createAccount()
    setupTokenVault(player)
    mintTokens(player.address, UFix64(100.0))

    let positionId = getTotalPositions()
    Test.expect(
        runTx("../transactions/staking/stake_position.cdc", [UFix64(100.0), UInt64(2)], player),
        Test.beSucceeded()
    )

    // Advance blocks past lock period
    Test.commitBlock()
    Test.commitBlock()
    Test.commitBlock()

    // Act — unstake
    let unstakeResult = runTx(
        "../transactions/staking/unstake_position.cdc",
        [positionId],
        player
    )
    Test.expect(unstakeResult, Test.beSucceeded())

    // Assert — principal returned to player
    Test.assertEqual(getBalance(player.address), UFix64(100.0))
}

/// Yield calculation: stake, advance blocks, claim yield, verify balance increase.
access(all) fun testYieldCalculation() {
    // Arrange — fund yield pool first (anyone can call fundYieldPool)
    // Fund the yield pool from deployer
    setupTokenVault(deployer)
    mintTokens(deployer.address, UFix64(1000.0))

    Test.expect(
        runTx("../transactions/staking/fund_yield_pool.cdc", [UFix64(500.0)], deployer),
        Test.beSucceeded()
    )
    Test.assert(getYieldPoolBalance() >= UFix64(500.0), message: "Yield pool not funded")

    // Stake 1000 tokens with yieldRatePerMille = 10 (default)
    let player = Test.createAccount()
    setupTokenVault(player)
    mintTokens(player.address, UFix64(1000.0))

    let positionId = getTotalPositions()
    Test.expect(
        runTx("../transactions/staking/stake_position.cdc", [UFix64(1000.0), UInt64(2)], player),
        Test.beSucceeded()
    )

    // Advance exactly 100 blocks
    // Yield = 1000 * 10 * 100 / 1_000_000 = 1.0 token
    var i = 0
    while i < 100 {
        Test.commitBlock()
        i = i + 1
    }

    let balanceBefore = getBalance(player.address)

    // Act — claim yield
    let claimResult = runTx(
        "../transactions/staking/claim_yield.cdc",
        [positionId],
        player
    )
    Test.expect(claimResult, Test.beSucceeded())

    // Assert — balance increased by yield amount
    let balanceAfter = getBalance(player.address)
    // yield = 1000.0 * 10 * 100 / 1_000_000 = 1.0 (approximately; exact blocks may vary by 1)
    Test.assert(
        balanceAfter > balanceBefore,
        message: "Balance should have increased after yield claim"
    )
}

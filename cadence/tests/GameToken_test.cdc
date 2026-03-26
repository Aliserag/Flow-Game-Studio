// cadence/tests/GameToken_test.cdc
// Tests for GameToken fungible token contract.
//
// API notes (Flow CLI v2.12.0):
//   - Test.deployContract() deploys a contract to 0x0000000000000007 in the test environment.
//   - Test.executeScript() returns a Test.ScriptResult; use .returnValue! to extract value.
//   - Test.executeTransaction() requires a Test.Transaction struct (not a path string).
//   - Test.readFile() loads transaction/script code from a path.
import Test
import "GameToken"
import "FungibleToken"

// Deployer account — 0x0000000000000007 in the test environment
access(all) let deployer = Test.getAccount(0x0000000000000007)

// -------------------------------------------------------------------------
// setup() — deploys GameToken ONCE before all tests
// -------------------------------------------------------------------------

access(all) fun setup() {
    let err = Test.deployContract(
        name: "GameToken",
        path: "../contracts/core/GameToken.cdc",
        arguments: ["Gold", "GOLD", UFix64(1_000_000_000.0)]
    )
    Test.expect(err, Test.beNil())
}

// -------------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------------

/// Run a file-based transaction signed by `signer`.
access(all) fun runTx(_ path: String, _ args: [AnyStruct], _ signer: Test.TestAccount): Test.TransactionResult {
    let tx = Test.Transaction(
        code: Test.readFile(path),
        authorizers: [signer.address],
        signers: [signer],
        arguments: args
    )
    return Test.executeTransaction(tx)
}

/// Query a UFix64 value from the chain via inline script.
access(all) fun queryUFix64(_ code: String): UFix64 {
    let result = Test.executeScript(code, [])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UFix64
}

/// Get token balance for an address using the get_token_balance script.
access(all) fun getBalance(_ address: Address): UFix64 {
    let result = Test.executeScript(
        Test.readFile("../scripts/get_token_balance.cdc"),
        [address]
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UFix64
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

/// Contract deploys with totalSupply == 0 and maxSupply == 1_000_000_000
access(all) fun testDeployment() {
    let totalSupply = queryUFix64(
        "import GameToken from 0x0000000000000007\naccess(all) fun main(): UFix64 { return GameToken.totalSupply }"
    )
    Test.assertEqual(totalSupply, UFix64(0.0))

    let maxSupply = queryUFix64(
        "import GameToken from 0x0000000000000007\naccess(all) fun main(): UFix64 { return GameToken.maxSupply }"
    )
    Test.assertEqual(maxSupply, UFix64(1_000_000_000.0))
}

/// Player can set up a vault and it starts with zero balance
access(all) fun testVaultSetup() {
    let player = Test.createAccount()

    let txResult = runTx("../transactions/token/setup_token_vault.cdc", [], player)
    Test.expect(txResult, Test.beSucceeded())

    let balance = getBalance(player.address)
    Test.assertEqual(balance, UFix64(0.0))
}

/// Deployer mints 1000 tokens to player; balance reflects it
access(all) fun testMintAndBalance() {
    let player = Test.createAccount()

    // Setup vault first
    let setupResult = runTx("../transactions/token/setup_token_vault.cdc", [], player)
    Test.expect(setupResult, Test.beSucceeded())

    // Mint 1000 tokens
    let mintTx = Test.Transaction(
        code: Test.readFile("../transactions/token/mint_tokens.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [player.address, UFix64(1000.0)]
    )
    let mintResult = Test.executeTransaction(mintTx)
    Test.expect(mintResult, Test.beSucceeded())

    let balance = getBalance(player.address)
    Test.assertEqual(balance, UFix64(1000.0))
}

/// Minting beyond maxSupply must fail
access(all) fun testMaxSupplyEnforced() {
    let player = Test.createAccount()

    let setupResult = runTx("../transactions/token/setup_token_vault.cdc", [], player)
    Test.expect(setupResult, Test.beSucceeded())

    // Attempt to mint more than maxSupply (1_000_000_001 > 1_000_000_000)
    let overMintTx = Test.Transaction(
        code: Test.readFile("../transactions/token/mint_tokens.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [player.address, UFix64(1_000_000_001.0)]
    )
    let overMintResult = Test.executeTransaction(overMintTx)
    Test.expect(overMintResult, Test.beFailed())
}

/// Player can transfer tokens to another player
access(all) fun testTransfer() {
    let sender = Test.createAccount()
    let receiver = Test.createAccount()

    // Setup vaults
    Test.expect(runTx("../transactions/token/setup_token_vault.cdc", [], sender), Test.beSucceeded())
    Test.expect(runTx("../transactions/token/setup_token_vault.cdc", [], receiver), Test.beSucceeded())

    // Mint 500 to sender
    let mintTx = Test.Transaction(
        code: Test.readFile("../transactions/token/mint_tokens.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [sender.address, UFix64(500.0)]
    )
    Test.expect(Test.executeTransaction(mintTx), Test.beSucceeded())

    // Transfer 200 from sender to receiver
    let transferTx = Test.Transaction(
        code: Test.readFile("../transactions/token/transfer_tokens.cdc"),
        authorizers: [sender.address],
        signers: [sender],
        arguments: [receiver.address, UFix64(200.0)]
    )
    Test.expect(Test.executeTransaction(transferTx), Test.beSucceeded())

    Test.assertEqual(getBalance(sender.address), UFix64(300.0))
    Test.assertEqual(getBalance(receiver.address), UFix64(200.0))
}

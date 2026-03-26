// cadence/tests/VersionRegistry_test.cdc
//
// Tests for the VersionRegistry contract.
//
// Covers:
//   - testDeployment: registry is empty after deploy
//   - testRegister: register a version, getLatestVersion returns it
//   - testHistory: register two versions, getHistory returns both in order

import Test

// Deployer account — 0x0000000000000007 in the test environment
access(all) let deployer = Test.getAccount(0x0000000000000007)

// -------------------------------------------------------------------------
// setup() — deploys VersionRegistry before all tests
// -------------------------------------------------------------------------

access(all) fun setup() {
    let err = Test.deployContract(
        name: "VersionRegistry",
        path: "../contracts/systems/VersionRegistry.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
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

/// Register a version via inline Cadence (bypasses the transaction for simplicity in test).
access(all) fun registerVersion(
    _ name: String,
    _ version: String,
    _ network: String,
    _ codeHash: String,
    _ changelog: String,
    _ signer: Test.TestAccount
) {
    let result = runTx(
        "../transactions/registry/register_version.cdc",
        [name, version, network, codeHash, changelog],
        signer
    )
    Test.expect(result, Test.beSucceeded())
}

/// Returns the version string of the latest registered version, or nil.
access(all) fun getLatestVersionString(_ name: String): String? {
    let result = Test.executeScript(
        "import \"VersionRegistry\"\naccess(all) fun main(_ name: String): String? {\n    let v = VersionRegistry.getLatestVersion(name)\n    if v == nil { return nil }\n    return v!.version\n}",
        [name]
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue as! String?
}

/// Returns the deployer address of the latest registered version, or nil.
access(all) fun getLatestDeployer(_ name: String): Address? {
    let result = Test.executeScript(
        "import \"VersionRegistry\"\naccess(all) fun main(_ name: String): Address? {\n    let v = VersionRegistry.getLatestVersion(name)\n    if v == nil { return nil }\n    return v!.deployedBy\n}",
        [name]
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue as! Address?
}

/// Returns the count of versions in history for a contract name.
access(all) fun getHistoryCount(_ name: String): Int {
    let result = Test.executeScript(
        "import \"VersionRegistry\"\naccess(all) fun main(_ name: String): Int {\n    return VersionRegistry.getHistory(name).length\n}",
        [name]
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! Int
}

/// Returns version string at index `idx` in history for a contract name.
access(all) fun getHistoryVersionAt(_ name: String, _ idx: Int): String {
    let result = Test.executeScript(
        "import \"VersionRegistry\"\naccess(all) fun main(_ name: String, _ idx: Int): String {\n    return VersionRegistry.getHistory(name)[idx].version\n}",
        [name, idx]
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! String
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

/// Registry is empty immediately after deployment.
access(all) fun testDeployment() {
    // Assert — unknown contract returns nil / empty history
    let latestVersion = getLatestVersionString("UnknownContract")
    Test.assertEqual(latestVersion == nil, true)

    let historyCount = getHistoryCount("UnknownContract")
    Test.assertEqual(historyCount, 0)
}

/// Register a single version; getLatestVersion returns it with correct fields.
access(all) fun testRegister() {
    // Arrange
    let contractName = "GameNFT"
    let version      = "1.0.0"
    let network      = "testnet"
    let codeHash     = "abc123def456"
    let changelog    = "Initial release"

    // Act — send the register_version transaction signed by deployer
    registerVersion(contractName, version, network, codeHash, changelog, deployer)

    // Assert — getLatestVersion returns the registered version string
    let latestVersion = getLatestVersionString(contractName)
    Test.assertEqual(latestVersion != nil, true)
    Test.assertEqual(latestVersion!, version)

    // Assert — deployer address recorded correctly
    let latestDeployer = getLatestDeployer(contractName)
    Test.assertEqual(latestDeployer != nil, true)
    Test.assertEqual(latestDeployer!, deployer.address)
}

/// Register two versions; getHistory returns both in registration order.
access(all) fun testHistory() {
    // Arrange
    let contractName = "GameToken"
    let v1           = "1.0.0"
    let v2           = "1.1.0"

    // Act — register version 1.0.0
    registerVersion(contractName, v1, "emulator", "hash_v1", "Initial release", deployer)

    // Act — register version 1.1.0
    registerVersion(contractName, v2, "emulator", "hash_v2", "Add transfer fee", deployer)

    // Assert — history contains both entries in order
    let count = getHistoryCount(contractName)
    Test.assertEqual(count, 2)

    Test.assertEqual(getHistoryVersionAt(contractName, 0), v1)
    Test.assertEqual(getHistoryVersionAt(contractName, 1), v2)

    // Assert — getLatestVersion returns the most recent entry
    let latestVersion = getLatestVersionString(contractName)
    Test.assertEqual(latestVersion != nil, true)
    Test.assertEqual(latestVersion!, v2)
}

// cadence/tests/GameItem_test.cdc
// Tests for GameItem contract using Flow CLI v2.12.0 Cadence Testing Framework.
//
// API notes (Flow CLI v2.12.0):
//   - Contracts MUST be deployed via Test.deployContract() before their state
//     is accessible at runtime. Use setup() for this.
//   - After deployment, contract state is accessible via Test.executeScript().
//   - The top-level `import "X"` provides type access for type annotations only;
//     it does NOT give access to the deployed contract's runtime state.
//   - Test.Transaction{code, authorizers, signers, arguments}
//   - Test.executeTransaction(tx) -> Test.TransactionResult
//   - Test.executeScript(code, args) -> Test.ScriptResult
import Test
import "GameItem"

// -------------------------------------------------------------------------
// Module-level accounts
// -------------------------------------------------------------------------

// Deployer is the service account that holds GameServerRef after deployment
access(all) let deployer = Test.getAccount(0x0000000000000007)

// -------------------------------------------------------------------------
// setup() — deploys GameItem to the deployer account ONCE before all tests
// -------------------------------------------------------------------------

access(all) fun setup() {
    let err = Test.deployContract(
        name: "GameItem",
        path: "../contracts/core/GameItem.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

// -------------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------------

/// Executes a file-based transaction signed by `signer`.
access(all) fun runTx(_ path: String, _ args: [AnyStruct], _ signer: Test.TestAccount): Test.TransactionResult {
    let tx = Test.Transaction(
        code: Test.readFile(path),
        authorizers: [signer.address],
        signers: [signer],
        arguments: args
    )
    return Test.executeTransaction(tx)
}

/// Queries the deployed contract's totalItems counter via executeScript.
access(all) fun getTotalItems(): UInt64 {
    let result = Test.executeScript(
        "import GameItem from 0x0000000000000007\naccess(all) fun main(): UInt64 { return GameItem.totalItems }",
        []
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UInt64
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

/// Contract deploys with zero items (verified via executeScript)
access(all) fun testDeployment() {
    let total = getTotalItems()
    Test.assertEqual(total, UInt64(0))
}

/// Create a sword item: totalItems should increment to 1
access(all) fun testCreateItem() {
    // Arrange
    let initialState: {String: AnyStruct} = {"level": UInt32(1), "durability": UInt32(100)}

    // Act
    let result = runTx(
        "../transactions/items/create_item.cdc",
        ["sword", initialState],
        deployer
    )

    // Assert
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual(getTotalItems(), UInt64(1))
}

/// Update an item's state: transaction should succeed
access(all) fun testItemStateUpdate() {
    // Arrange — item 0 was created in testCreateItem (level=1)
    // Act
    let result = runTx(
        "../transactions/items/update_item_state.cdc",
        [UInt64(0), "level", UInt32(5)],
        deployer
    )

    // Assert: transaction succeeded — state update was applied
    Test.expect(result, Test.beSucceeded())
}

/// Create a second item: totalItems increments to 2
access(all) fun testMultipleItemsIncrementCounter() {
    // Arrange
    let initialState: {String: AnyStruct} = {"uses": UInt32(3)}

    // Act
    let result = runTx(
        "../transactions/items/create_item.cdc",
        ["potion", initialState],
        deployer
    )

    // Assert
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual(getTotalItems(), UInt64(2))
}

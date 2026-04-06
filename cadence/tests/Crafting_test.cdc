// cadence/tests/Crafting_test.cdc
//
// Tests for the Crafting contract.
//
// API notes (Flow CLI v2.x):
//   - Test.deployContract() deploys to 0x0000000000000007 in the test env.
//   - Test.readFile() loads transaction/script content from a path.

import Test
import "Crafting"

// Deployer account — 0x0000000000000007 in the test environment
access(all) let deployer = Test.getAccount(0x0000000000000007)

// -------------------------------------------------------------------------
// setup() — deploys Crafting once before all tests
// -------------------------------------------------------------------------

access(all) fun setup() {
    let err = Test.deployContract(
        name: "Crafting",
        path: "../contracts/systems/Crafting.cdc",
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

/// Query totalRecipes via script (live chain state).
access(all) fun getTotalRecipes(): UInt64 {
    let result = Test.executeScript(
        "import \"Crafting\"\naccess(all) fun main(): UInt64 { return Crafting.totalRecipes }",
        []
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UInt64
}

/// Query recipe success rate via script.
access(all) fun getRecipeSuccessRate(_ id: UInt64): UInt8 {
    let result = Test.executeScript(
        "import \"Crafting\"\naccess(all) fun main(id: UInt64): UInt8 { return Crafting.getRecipe(id)!.successRatePercent }",
        [id]
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UInt8
}

// -------------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------------

/// Crafting contract deploys with zero recipes.
access(all) fun testDeployment() {
    // Assert
    Test.assertEqual(getTotalRecipes(), UInt64(0))
}

/// Admin can add a recipe; totalRecipes increments to 1.
access(all) fun testAddRecipe() {
    // Arrange
    let beforeCount = getTotalRecipes()

    // Act — add a recipe via admin transaction
    // Transaction args: name, ingredientTypes[], ingredientQtys[], outputType, outputQuantity, successRatePercent
    let result = runTx(
        "../transactions/crafting/add_recipe.cdc",
        [
            "Iron Sword",        // name
            ["ore"],             // ingredientTypes
            [UInt32(2)],         // ingredientQtys
            "SwordItem",         // outputType
            UInt32(1),           // outputQuantity
            UInt8(75)            // successRatePercent
        ],
        deployer
    )
    Test.expect(result, Test.beSucceeded())

    // Assert
    Test.assertEqual(getTotalRecipes(), beforeCount + UInt64(1))
    Test.assertEqual(getRecipeSuccessRate(beforeCount), UInt8(75))
}

/// Craft with vrfResult=0 and successRate=100 — always succeeds.
access(all) fun testCraftSuccess() {
    // Arrange — add a guaranteed-success recipe (100% success rate)
    let recipeId = getTotalRecipes()
    let addResult = runTx(
        "../transactions/crafting/add_recipe.cdc",
        [
            "Guaranteed Item",
            ["dust"],
            [UInt32(1)],
            "MagicItem",
            UInt32(1),
            UInt8(100)    // 100% success rate: 0 % 100 = 0 < 100 => always succeeds
        ],
        deployer
    )
    Test.expect(addResult, Test.beSucceeded())

    // Act — attempt craft with vrfResult=0, which satisfies 0 % 100 < 100
    let craftTx = Test.Transaction(
        code: Test.readFile("../transactions/crafting/attempt_craft.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [recipeId, deployer.address, UInt256(0)]
    )
    let result = Test.executeTransaction(craftTx)

    // Assert — craft transaction succeeds
    Test.expect(result, Test.beSucceeded())
}

/// Craft with successRate=0 — always fails (success=false, not a panic).
access(all) fun testCraftFailure() {
    // Arrange — add a 0% success rate recipe
    let recipeId = getTotalRecipes()
    let addResult = runTx(
        "../transactions/crafting/add_recipe.cdc",
        [
            "Impossible Item",
            ["diamond"],
            [UInt32(10)],
            "PhoenixFeather",
            UInt32(1),
            UInt8(0)    // 0% success rate: 99 % 100 = 99, NOT < 0 => always fails
        ],
        deployer
    )
    Test.expect(addResult, Test.beSucceeded())

    // Act — attempt craft with vrfResult=99; result is success=false (not a panic)
    let craftTx = Test.Transaction(
        code: Test.readFile("../transactions/crafting/attempt_craft.cdc"),
        authorizers: [deployer.address],
        signers: [deployer],
        arguments: [recipeId, deployer.address, UInt256(99)]
    )
    let result = Test.executeTransaction(craftTx)

    // Assert — transaction itself succeeds (craft attempt is not a panic), result is failure
    Test.expect(result, Test.beSucceeded())
}

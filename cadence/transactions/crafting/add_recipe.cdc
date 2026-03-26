// cadence/transactions/crafting/add_recipe.cdc
//
// Admin transaction: adds a new crafting recipe.
// Signer must own the CraftingAdmin resource (deployer account).
import "Crafting"

transaction(
    name: String,
    ingredientTypes: [String],
    ingredientQtys: [UInt32],
    outputType: String,
    outputQuantity: UInt32,
    successRatePercent: UInt8
) {
    prepare(signer: auth(Storage) &Account) {
        // Build ingredients array from parallel arrays
        var ingredients: [Crafting.Ingredient] = []
        var i = 0
        while i < ingredientTypes.length {
            ingredients.append(Crafting.Ingredient(
                itemType: ingredientTypes[i],
                quantity: ingredientQtys[i]
            ))
            i = i + 1
        }

        // Borrow Admin reference with Admin entitlement
        let adminRef = signer.storage.borrow<auth(Crafting.Admin) &Crafting.AdminRef>(
            from: /storage/CraftingAdmin
        ) ?? panic("No CraftingAdmin resource found — must be deployer account")

        adminRef.addRecipe(
            name: name,
            ingredients: ingredients,
            outputType: outputType,
            outputQuantity: outputQuantity,
            successRatePercent: successRatePercent
        )
    }
}

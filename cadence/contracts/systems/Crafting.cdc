// cadence/contracts/systems/Crafting.cdc
//
// Crafting system for Flow game studios.
//
// Design:
//   - Admin defines CraftingRecipes with ingredients, output, and success rates.
//   - Players attempt crafts via a VRF result (commit/reveal pattern handled externally).
//   - Success is determined by: vrfResult % 100 < successRatePercent.
//   - Crafting does NOT interact with GameItem directly — it returns a success bool
//     and outputType; the client handles actual item creation.
//
// Struct mutation note:
//   Uses flat-state maps for mutable recipe fields following the Tournament pattern.
//   RecipeCore holds immutable data written once; mutable fields tracked separately.

access(all) contract Crafting {

    // -----------------------------------------------------------------------
    // Entitlements
    // -----------------------------------------------------------------------

    /// Admin entitlement — held only by the AdminRef resource stored at deployer.
    access(all) entitlement Admin

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// Fires when a new recipe is added by the Admin.
    access(all) event RecipeAdded(id: UInt64, name: String, outputType: String, successRatePercent: UInt8)

    /// Fires on every craft attempt, successful or not.
    access(all) event CraftAttempted(recipeId: UInt64, player: Address, success: Bool)

    // -----------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------

    /// One ingredient requirement in a recipe.
    access(all) struct Ingredient {
        access(all) let itemType: String
        access(all) let quantity: UInt32

        init(itemType: String, quantity: UInt32) {
            self.itemType = itemType
            self.quantity = quantity
        }
    }

    /// Public read-only view of a recipe — assembled by getRecipe().
    access(all) struct CraftingRecipe {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let ingredients: [Ingredient]
        access(all) let outputType: String
        access(all) let outputQuantity: UInt32
        access(all) let successRatePercent: UInt8  // 0–100

        init(
            id: UInt64,
            name: String,
            ingredients: [Ingredient],
            outputType: String,
            outputQuantity: UInt32,
            successRatePercent: UInt8
        ) {
            self.id                 = id
            self.name               = name
            self.ingredients        = ingredients
            self.outputType         = outputType
            self.outputQuantity     = outputQuantity
            self.successRatePercent = successRatePercent
        }
    }

    // -----------------------------------------------------------------------
    // Immutable core data (written once at addRecipe)
    // -----------------------------------------------------------------------

    /// Immutable per-recipe config — stored once, never mutated.
    /// access(all) required by Cadence 1.0: type declarations must be public.
    access(all) struct RecipeCore {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let ingredients: [Ingredient]
        access(all) let outputType: String
        access(all) let outputQuantity: UInt32
        access(all) let successRatePercent: UInt8

        init(
            id: UInt64,
            name: String,
            ingredients: [Ingredient],
            outputType: String,
            outputQuantity: UInt32,
            successRatePercent: UInt8
        ) {
            self.id                 = id
            self.name               = name
            self.ingredients        = ingredients
            self.outputType         = outputType
            self.outputQuantity     = outputQuantity
            self.successRatePercent = successRatePercent
        }
    }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// Total recipes ever added (also the next recipe ID).
    access(all) var totalRecipes: UInt64

    /// Recipe data keyed by recipe ID.
    access(self) var recipes: {UInt64: RecipeCore}

    // -----------------------------------------------------------------------
    // Admin Resource
    // -----------------------------------------------------------------------

    /// AdminRef — stored at deployer account; never published to a public path.
    access(all) resource AdminRef {

        /// Add a new crafting recipe. Panics if successRatePercent > 100.
        access(Admin) fun addRecipe(
            name: String,
            ingredients: [Ingredient],
            outputType: String,
            outputQuantity: UInt32,
            successRatePercent: UInt8
        ): UInt64 {
            pre {
                name.length > 0:         "Recipe name cannot be empty"
                outputType.length > 0:   "Output type cannot be empty"
                outputQuantity > UInt32(0): "Output quantity must be > 0"
                successRatePercent <= UInt8(100): "Success rate must be 0–100"
            }

            let id = Crafting.totalRecipes

            Crafting.recipes[id] = RecipeCore(
                id: id,
                name: name,
                ingredients: ingredients,
                outputType: outputType,
                outputQuantity: outputQuantity,
                successRatePercent: successRatePercent
            )
            Crafting.totalRecipes = Crafting.totalRecipes + 1

            emit RecipeAdded(id: id, name: name, outputType: outputType, successRatePercent: successRatePercent)
            return id
        }
    }

    // -----------------------------------------------------------------------
    // Public functions
    // -----------------------------------------------------------------------

    /// Attempt a craft. Caller passes a VRF result (from RandomVRF.reveal).
    /// Returns (success, outputType). Client is responsible for item creation.
    ///
    /// Success condition: vrfResult % 100 < UInt256(successRatePercent)
    /// A recipe with successRatePercent = 100 always succeeds.
    /// A recipe with successRatePercent = 0  always fails.
    access(all) fun craft(
        recipeId: UInt64,
        playerAddress: Address,
        vrfResult: UInt256
    ): {String: AnyStruct} {
        let recipe = self.recipes[recipeId]
            ?? panic("Recipe not found: ".concat(recipeId.toString()))

        let roll = vrfResult % UInt256(100)
        let success = roll < UInt256(recipe.successRatePercent)

        emit CraftAttempted(recipeId: recipeId, player: playerAddress, success: success)

        return {
            "success":        success,
            "outputType":     recipe.outputType,
            "outputQuantity": recipe.outputQuantity,
            "recipeId":       recipeId
        }
    }

    /// Get a recipe by ID, or nil if not found.
    /// Not `view` because struct construction is not permitted in view context in Cadence 1.0.
    access(all) fun getRecipe(_ id: UInt64): CraftingRecipe? {
        if let core = self.recipes[id] {
            return CraftingRecipe(
                id: core.id,
                name: core.name,
                ingredients: core.ingredients,
                outputType: core.outputType,
                outputQuantity: core.outputQuantity,
                successRatePercent: core.successRatePercent
            )
        }
        return nil
    }

    // -----------------------------------------------------------------------
    // Init
    // -----------------------------------------------------------------------

    init() {
        self.totalRecipes = 0
        self.recipes      = {}

        self.account.storage.save(<- create AdminRef(), to: /storage/CraftingAdmin)
    }
}

// cadence/transactions/crafting/attempt_craft.cdc
//
// Attempt a craft using a VRF result.
// In production the vrfResult comes from RandomVRF.reveal(); here it is passed directly
// to keep the transaction composable (the commit/reveal happens in a separate step).
//
// The transaction emits a CraftAttempted event; the caller must read the event or
// use a script to determine whether the craft succeeded before attempting item creation.
import "Crafting"

transaction(recipeId: UInt64, playerAddress: Address, vrfResult: UInt256) {

    prepare(signer: auth(Storage) &Account) {
        // No storage operations needed — craft() is a pure contract function.
        // We just call it and let the event propagate the outcome.
        let _ = Crafting.craft(
            recipeId: recipeId,
            playerAddress: playerAddress,
            vrfResult: vrfResult
        )
    }
}

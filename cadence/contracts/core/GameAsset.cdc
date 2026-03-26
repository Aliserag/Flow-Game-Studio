// cadence/contracts/core/GameAsset.cdc
// Common interface for all game assets: NFTs, items, tokens, and game state objects.
// Every on-chain game asset in this studio implements this interface.
//
// Usage: `access(all) contract MyAsset: GameAsset { ... }`
// The contract must implement the `createAsset` factory function and the
// `Asset` resource interface on all asset resources it exposes.
access(all) contract interface GameAsset {

    // Owner entitlement: held by the player who controls the asset
    access(all) entitlement Owner
    // GameServer entitlement: held by the privileged game server resource
    access(all) entitlement GameServer
    // Admin entitlement: held by the contract deployer/admin resource
    access(all) entitlement Admin

    /// Every asset has a unique ID and a game-defined type string.
    access(all) resource interface Asset {
        access(all) let id: UInt64
        // e.g. "weapon", "character", "consumable"
        access(all) let assetType: String
        // Scheduler epoch when created
        access(all) let createdAtEpoch: UInt64
        // Increments on upgrades
        access(all) var version: UInt32

        /// Game server can update mutable game state
        access(GameServer) fun updateState(key: String, value: AnyStruct)

        /// Returns all mutable state as a dict (read-only copy)
        access(all) fun getState(): {String: AnyStruct}
    }

    /// Every game asset contract must implement this factory function
    access(all) fun createAsset(
        assetType: String,
        initialState: {String: AnyStruct}
    ): @{Asset}
}

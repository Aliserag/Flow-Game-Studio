// cadence/contracts/core/GameItem.cdc
// Non-NFT game item: equipment, consumables, crafting materials.
// Items are owned by player accounts but are NOT tradable on external marketplaces
// unless wrapped in an NFT. They represent in-game state, not tradable assets.
//
// Pattern:
//   - `Item` resource holds immutable identity fields and mutable game state.
//   - `Bag` resource is the player-owned container for items.
//   - `GameServerRef` is a privileged resource (stored at deployer; never published)
//     that can create items and trigger state updates via an auth(GameServer) &Bag.
//   - The `GameServer` entitlement controls all mutation paths.
//
// Note: GameItem.Item is intentionally compatible with GameAsset.Asset but does not
// formally implement it (GameAsset uses `createdAtEpoch` while this contract tracks
// `createdAtBlock`). Implement GameAsset explicitly in a higher-level wrapper contract.

access(all) contract GameItem {

    // GameServer entitlement: held only by the GameServerRef resource (deployer account)
    access(all) entitlement GameServer
    // Owner entitlement: held by the player who owns the Bag
    access(all) entitlement Owner

    // Fires after an item is deposited into a Bag
    access(all) event ItemCreated(id: UInt64, assetType: String, owner: Address?)
    // Fires after a game-server state update
    access(all) event ItemStateUpdated(id: UInt64, key: String)
    // Fires when an item resource is destroyed
    access(all) event ItemDestroyed(id: UInt64)

    // Monotonically increasing counter; never decrements
    access(all) var totalItems: UInt64

    access(all) let StoragePath: StoragePath
    access(all) let PublicPath:  PublicPath

    // -------------------------------------------------------------------------
    // Item resource
    // -------------------------------------------------------------------------
    access(all) resource Item {
        access(all) let id:            UInt64
        access(all) let assetType:     String
        access(all) let createdAtBlock: UInt64
        access(all) var version:       UInt32
        // Mutable game-state dict; only writable via GameServer entitlement
        access(all) var state:         {String: AnyStruct}

        /// Only callable through an auth(GameServer) reference — see Bag.updateItemState
        access(GameServer) fun updateState(key: String, value: AnyStruct) {
            self.state[key] = value
            self.version = self.version + 1
            emit ItemStateUpdated(id: self.id, key: key)
        }

        /// Read-only snapshot of all mutable state
        access(all) fun getState(): {String: AnyStruct} { return self.state }

        init(id: UInt64, assetType: String, initialState: {String: AnyStruct}) {
            self.id             = id
            self.assetType      = assetType
            self.createdAtBlock = getCurrentBlock().height
            self.version        = 0
            self.state          = initialState
        }
    }

    // -------------------------------------------------------------------------
    // Bag: player-owned item container
    // -------------------------------------------------------------------------
    access(all) resource Bag {
        // Resource dictionary — publicly readable; mutation requires entitlements
        access(all) var items: @{UInt64: Item}

        /// Deposit an item into this Bag.
        /// Requires Owner entitlement so only the Bag holder can deposit.
        access(Owner) fun deposit(item: @Item) {
            let id        = item.id
            let assetType = item.assetType
            let old      <- self.items[id] <- item
            destroy old
            emit ItemCreated(id: id, assetType: assetType, owner: self.owner?.address)
        }

        /// Withdraw an item from this Bag.
        /// Requires Owner entitlement.
        access(Owner) fun withdraw(id: UInt64): @Item {
            return <- (self.items.remove(key: id)
                ?? panic("Item not found: ".concat(id.toString())))
        }

        /// Game server updates a single state key on an item in this Bag.
        /// Requires GameServer entitlement — only GameServerRef can call this.
        access(GameServer) fun updateItemState(itemId: UInt64, key: String, value: AnyStruct) {
            let itemRef = (&self.items[itemId] as auth(GameServer) &Item?)
                ?? panic("Item not found: ".concat(itemId.toString()))
            itemRef.updateState(key: key, value: value)
        }

        /// Returns all item IDs held in this Bag
        access(all) fun getIDs(): [UInt64] { return self.items.keys }

        /// Borrow a read-only reference to an item
        access(all) fun getItem(_ id: UInt64): &Item? { return &self.items[id] }

        init() { self.items <- {} }
    }

    // -------------------------------------------------------------------------
    // GameServerRef: privileged resource stored only at the deployer account
    // Never published to a public capability path.
    // -------------------------------------------------------------------------
    access(all) resource GameServerRef {
        /// Mint a new Item; caller deposits it into the target Bag.
        access(all) fun createItem(assetType: String, initialState: {String: AnyStruct}): @Item {
            let id = GameItem.totalItems
            GameItem.totalItems = GameItem.totalItems + 1
            return <- create Item(id: id, assetType: assetType, initialState: initialState)
        }

        /// Update an item's state through the Bag's GameServer-gated function.
        /// `bagRef` must be auth(GameServer) — only this resource produces such a ref
        /// (via a storage borrow with the GameServer entitlement).
        access(all) fun updateItemState(
            bagRef: auth(GameServer) &GameItem.Bag,
            itemId: UInt64,
            key:    String,
            value:  AnyStruct
        ) {
            bagRef.updateItemState(itemId: itemId, key: key, value: value)
        }
    }

    /// Creates a new empty Bag for a player account
    access(all) fun createEmptyBag(): @Bag { return <- create Bag() }

    // -------------------------------------------------------------------------
    // Init
    // -------------------------------------------------------------------------
    init() {
        self.totalItems  = 0
        self.StoragePath = /storage/GameItemBag
        self.PublicPath  = /public/GameItemBag

        // GameServerRef is stored privately at the deployer — never published
        self.account.storage.save(<- create GameServerRef(), to: /storage/GameItemServer)
    }
}

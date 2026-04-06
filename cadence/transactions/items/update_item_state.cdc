// cadence/transactions/items/update_item_state.cdc
// Updates a single state key on a GameItem in the signer's Bag.
// Requires the signer to hold the GameServerRef (i.e., the deployer account).
import "GameItem"

transaction(itemId: UInt64, key: String, value: AnyStruct) {
    prepare(signer: auth(Storage) &Account) {
        // Borrow the privileged GameServerRef
        let serverRef = signer.storage.borrow<&GameItem.GameServerRef>(
            from: /storage/GameItemServer
        ) ?? panic("GameServerRef not found — only the deployer can update item state")

        // Borrow the Bag with the GameServer entitlement so the server-gated
        // Bag.updateItemState function can be called
        let bag = signer.storage.borrow<auth(GameItem.GameServer) &GameItem.Bag>(
            from: GameItem.StoragePath
        ) ?? panic("Bag not found")

        serverRef.updateItemState(bagRef: bag, itemId: itemId, key: key, value: value)
    }
}

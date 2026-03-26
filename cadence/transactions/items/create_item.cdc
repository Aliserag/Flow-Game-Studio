// cadence/transactions/items/create_item.cdc
// Creates a new GameItem and deposits it into the signer's Bag.
// In production, only the deployer account holds a GameServerRef and can create items.
// In the emulator / tests, the deployer acts as both game server and test player.
import "GameItem"

transaction(assetType: String, initialState: {String: AnyStruct}) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Set up Bag if the signer does not have one yet
        if signer.storage.borrow<&GameItem.Bag>(from: GameItem.StoragePath) == nil {
            signer.storage.save(<- GameItem.createEmptyBag(), to: GameItem.StoragePath)
            let cap = signer.capabilities.storage.issue<&GameItem.Bag>(GameItem.StoragePath)
            signer.capabilities.publish(cap, at: GameItem.PublicPath)
        }

        // Borrow the GameServerRef — only the deployer account has this
        let serverRef = signer.storage.borrow<&GameItem.GameServerRef>(
            from: /storage/GameItemServer
        ) ?? panic("GameServerRef not found — only the deployer can create items")

        // Mint the item
        let item <- serverRef.createItem(assetType: assetType, initialState: initialState)

        // Deposit into the signer's Bag (requires Owner entitlement)
        let bag = signer.storage.borrow<auth(GameItem.Owner) &GameItem.Bag>(
            from: GameItem.StoragePath
        ) ?? panic("Bag not found after setup")

        bag.deposit(item: <- item)
    }
}

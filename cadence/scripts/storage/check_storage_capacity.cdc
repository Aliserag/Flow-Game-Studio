// Returns storage usage summary for an account.
// Use before minting to check if the player has sufficient capacity.

access(all) fun main(address: Address): {String: UInt64} {
    let account = getAccount(address)
    return {
        "used":      account.storage.used,
        "capacity":  account.storage.capacity,
        "available": account.storage.capacity - account.storage.used,
        "flowBalance": UInt64(getAccount(address).balance * 100_000_000.0)  // in micro-FLOW
    }
}

import "FungibleToken"
import "GameToken"

access(all) fun main(address: Address): UFix64 {
    return getAccount(address)
        .capabilities.get<&GameToken.Vault>(GameToken.VaultPublicPath)
        .borrow()?.balance ?? 0.0
}

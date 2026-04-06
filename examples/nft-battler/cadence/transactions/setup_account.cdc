// setup_account.cdc — Create empty Fighter and PowerUp collections for a player.
// Call this once per account before minting or receiving any NFTs.
// Idempotent: safe to call multiple times — skips if collections already exist.

import NonFungibleToken from "NonFungibleToken"
import Fighter from "Fighter"
import PowerUp from "PowerUp"

transaction {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Fighter collection
        if signer.storage.borrow<&Fighter.Collection>(from: Fighter.CollectionStoragePath) == nil {
            let collection <- Fighter.createEmptyCollection(nftType: Type<@Fighter.NFT>())
            signer.storage.save(<- collection, to: Fighter.CollectionStoragePath)
            let cap = signer.capabilities.storage.issue<&Fighter.Collection>(Fighter.CollectionStoragePath)
            signer.capabilities.publish(cap, at: Fighter.CollectionPublicPath)
        }

        // PowerUp collection
        if signer.storage.borrow<&PowerUp.Collection>(from: PowerUp.CollectionStoragePath) == nil {
            let collection <- PowerUp.createEmptyCollection(nftType: Type<@PowerUp.NFT>())
            signer.storage.save(<- collection, to: PowerUp.CollectionStoragePath)
            let cap = signer.capabilities.storage.issue<&PowerUp.Collection>(PowerUp.CollectionStoragePath)
            signer.capabilities.publish(cap, at: PowerUp.CollectionPublicPath)
        }
    }
}

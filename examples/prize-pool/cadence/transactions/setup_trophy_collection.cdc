/// setup_trophy_collection.cdc — Initialize a WinnerTrophy collection for the signer.
///
/// Players (and the admin) must run this before they can receive a WinnerTrophy NFT.
/// Idempotent — safe to run multiple times.

import "NonFungibleToken"
import "WinnerTrophy"

transaction {
    prepare(signer: auth(SaveValue, BorrowValue, IssueStorageCapabilityController, PublishCapability) &Account) {
        // Skip if collection already exists
        if signer.storage.borrow<&WinnerTrophy.Collection>(from: WinnerTrophy.CollectionStoragePath) != nil {
            log("WinnerTrophy collection already exists — skipping")
            return
        }

        // Create and save empty collection
        let collection <- WinnerTrophy.createEmptyCollection(nftType: Type<@WinnerTrophy.NFT>())
        signer.storage.save(<- collection, to: WinnerTrophy.CollectionStoragePath)

        // Publish public capability
        let cap = signer.capabilities.storage.issue<&WinnerTrophy.Collection>(
            WinnerTrophy.CollectionStoragePath
        )
        signer.capabilities.publish(cap, at: WinnerTrophy.CollectionPublicPath)

        log("WinnerTrophy collection created and published")
    }
}

// cadence/transactions/achievement/setup_achievement_collection.cdc
//
// Set up an AchievementCollection for the signing account.
// Must be called before any achievement can be granted to this account.
// Idempotent: safe to call multiple times.
import "Achievement"

transaction {

    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Idempotent: skip if collection already exists
        if signer.storage.borrow<&Achievement.AchievementCollection>(
            from: Achievement.CollectionStoragePath
        ) != nil {
            return
        }

        // Save a new empty collection to storage
        signer.storage.save(
            <- Achievement.createEmptyCollection(),
            to: Achievement.CollectionStoragePath
        )

        // Publish read capability so GameServerRef can deposit into it
        let cap = signer.capabilities.storage.issue<&Achievement.AchievementCollection>(
            Achievement.CollectionStoragePath
        )
        signer.capabilities.publish(cap, at: Achievement.CollectionPublicPath)
    }
}

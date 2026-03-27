// create_profile.cdc
// Creates a soul-bound PlayerProfile for a new player.
// Call once per account — profile cannot be transferred after creation.

import PlayerProfile from 0xPLAYER_PROFILE_ADDRESS

transaction(displayName: String) {
    prepare(player: auth(Storage, Capabilities) &Account) {
        // Skip if profile already exists
        if player.storage.borrow<&PlayerProfile.Collection>(
            from: PlayerProfile.CollectionStoragePath
        ) != nil {
            return
        }

        // Create and save the collection
        let collection <- PlayerProfile.createCollection()
        player.storage.save(<-collection, to: PlayerProfile.CollectionStoragePath)

        // Publish read-only public capability
        let cap = player.capabilities.storage.issue<&{PlayerProfile.Collection}>(
            PlayerProfile.CollectionStoragePath
        )
        player.capabilities.publish(cap, at: PlayerProfile.CollectionPublicPath)

        // Create and store the profile
        let collection2 = player.storage.borrow<auth(PlayerProfile.ProfileUpdate) &PlayerProfile.Collection>(
            from: PlayerProfile.CollectionStoragePath
        )!
        let profile <- PlayerProfile.createProfile(
            owner: player.address,
            displayName: displayName
        )
        collection2.setProfile(<-profile)

        log("PlayerProfile created: ".concat(displayName))
    }
}

// cadence/transactions/achievement/grant_achievement.cdc
//
// Grant a soulbound achievement to a player.
// Signer must own the GameServerRef resource (deployer account).
// Player must have set up an AchievementCollection first.
import "Achievement"

transaction(
    player: Address,
    achievementType: String,
    name: String,
    description: String
) {

    prepare(signer: auth(Storage) &Account) {
        // Borrow GameServerRef with GameServer entitlement
        let serverRef = signer.storage.borrow<auth(Achievement.GameServer) &Achievement.GameServerRef>(
            from: Achievement.GameServerStoragePath
        ) ?? panic("No GameServerRef found — must be deployer account")

        serverRef.grantAchievement(
            player: player,
            achievementType: achievementType,
            name: name,
            description: description
        )
    }
}

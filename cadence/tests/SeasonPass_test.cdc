import Test
import "SeasonPass"
import "EmergencyPause"

access(all) fun testSeasonLifecycle() {
    let admin = Test.getAccount(0x0000000000000001)
    Test.deployContract(name: "EmergencyPause", path: "../contracts/systems/EmergencyPause.cdc", arguments: [])
    Test.deployContract(name: "SeasonPass", path: "../contracts/liveops/SeasonPass.cdc", arguments: [])

    // Start a season
    let startTx = Test.Transaction(
        code: `
            import "SeasonPass"
            transaction {
                prepare(signer: auth(BorrowValue) &Account) {
                    let a = signer.storage.borrow<auth(SeasonPass.SeasonAdmin) &SeasonPass.Admin>(
                        from: SeasonPass.AdminStoragePath) ?? panic("no admin")
                    let config = SeasonPass.SeasonConfig(
                        seasonId: 1, name: "Season 1", startEpoch: 0, endEpoch: 100,
                        maxTier: 10, xpPerTier: 100.0, freeRewards: {}, premiumRewards: {}
                    )
                    a.startSeason(config: config)
                }
            }
        `,
        args: [],
        signers: [admin]
    )
    Test.expect(Test.executeTransaction(startTx), Test.beSucceeded())
    Test.assertEqual("Season 1", SeasonPass.activeSeason?.name)

    // Award XP
    let xpTx = Test.Transaction(
        code: `
            import "SeasonPass"
            transaction {
                prepare(signer: auth(BorrowValue) &Account) {
                    let a = signer.storage.borrow<auth(SeasonPass.SeasonAdmin) &SeasonPass.Admin>(
                        from: SeasonPass.AdminStoragePath) ?? panic("no admin")
                    a.awardXP(player: signer.address, amount: 250.0)
                }
            }
        `,
        args: [],
        signers: [admin]
    )
    Test.expect(Test.executeTransaction(xpTx), Test.beSucceeded())

    let progress = SeasonPass.playerProgress[admin.address]!
    Test.assertEqual(250.0, progress.xp)
    Test.assertEqual(2, progress.currentTier)  // 250 XP / 100 per tier = tier 2
}

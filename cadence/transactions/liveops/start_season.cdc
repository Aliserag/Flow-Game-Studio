import "SeasonPass"

transaction(name: String, startEpoch: UInt64, endEpoch: UInt64, maxTier: UInt8, xpPerTier: UFix64) {
    let adminRef: auth(SeasonPass.SeasonAdmin) &SeasonPass.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        self.adminRef = signer.storage.borrow<auth(SeasonPass.SeasonAdmin) &SeasonPass.Admin>(
            from: SeasonPass.AdminStoragePath
        ) ?? panic("No SeasonPass.Admin in storage")
    }

    execute {
        let config = SeasonPass.SeasonConfig(
            seasonId: 1,
            name: name,
            startEpoch: startEpoch,
            endEpoch: endEpoch,
            maxTier: maxTier,
            xpPerTier: xpPerTier,
            freeRewards: {},
            premiumRewards: {}
        )
        self.adminRef.startSeason(config: config)
        log("Season started: ".concat(name))
    }
}

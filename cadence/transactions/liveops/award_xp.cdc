import "SeasonPass"

transaction(player: Address, amount: UFix64) {
    let adminRef: auth(SeasonPass.SeasonAdmin) &SeasonPass.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        self.adminRef = signer.storage.borrow<auth(SeasonPass.SeasonAdmin) &SeasonPass.Admin>(
            from: SeasonPass.AdminStoragePath
        ) ?? panic("No SeasonPass.Admin in storage")
    }

    execute {
        self.adminRef.awardXP(player: player, amount: amount)
        log("Awarded XP to ".concat(player.toString()))
    }
}

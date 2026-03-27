import "DungeonCrawler"

transaction(secret: UInt256, level: UInt8) {
    let playerAddress: Address

    prepare(signer: &Account) {
        self.playerAddress = signer.address
    }

    execute {
        DungeonCrawler.enterDungeon(
            player: self.playerAddress,
            secret: secret,
            level: level
        )
    }
}

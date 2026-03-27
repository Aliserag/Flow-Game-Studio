import "DungeonCrawler"
import "GameToken"

transaction(runId: UInt64, secret: UInt256) {
    let playerAddress: Address
    let minterRef: &GameToken.Minter
    let receiverRef: &{FungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {
        self.playerAddress = signer.address

        // Minter is held by the DungeonCrawler deployer account, not the player
        // In production: use a capability stored in DungeonCrawler contract
        self.minterRef = getAccount(DungeonCrawler.account.address)
            .storage.borrow<&GameToken.Minter>(from: GameToken.MinterStoragePath)
            ?? panic("No GameToken.Minter available")

        self.receiverRef = signer.storage.borrow<&{FungibleToken.Receiver}>(
            from: /storage/gameTokenVault
        ) ?? panic("No GameToken vault — set up vault first")
    }

    execute {
        DungeonCrawler.resolveDungeon(
            runId: runId,
            player: self.playerAddress,
            secret: secret,
            minterRef: self.minterRef,
            receiverRef: self.receiverRef
        )
    }
}

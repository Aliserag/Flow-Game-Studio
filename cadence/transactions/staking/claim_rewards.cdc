import "StakingPool"
import "GameToken"
import "FungibleToken"

transaction {
    let stakerAddress: Address
    let receiverRef: &{FungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {
        self.stakerAddress = signer.address
        self.receiverRef = signer.storage.borrow<&{FungibleToken.Receiver}>(
            from: GameToken.VaultStoragePath
        ) ?? panic("No GameToken vault receiver")
    }

    execute {
        StakingPool.claimRewards(staker: self.stakerAddress, receiver: self.receiverRef)
        log("Rewards claimed")
    }
}

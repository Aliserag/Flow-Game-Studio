import "FungibleToken"
import "FlowToken"
import "CoinFlip"

transaction(id: UInt64) {
    let buyer: Address

    prepare(signer: auth(BorrowValue) &Account) {
        self.buyer = signer.address
    }

    execute {
        CoinFlip.claimReward(poolId: id, userAddress: self.buyer)
    }
}

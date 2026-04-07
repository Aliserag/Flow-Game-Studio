import FungibleToken from 0xFungibleToken
import FlowToken from 0xFlowToken
import CoinFlip from 0xCoinFlip

transaction(id: UInt64) {
    let buyer: Address

    prepare(signer: auth(BorrowValue) &Account) {
        self.buyer = signer.address
    }

    execute {
        CoinFlip.claimReward(poolId: id, userAddress: self.buyer)
    }
}

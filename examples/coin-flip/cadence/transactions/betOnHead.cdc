import FungibleToken from 0xFungibleToken
import FlowToken from 0xFlowToken
import CoinFlip from 0xCoinFlip

transaction(id: UInt64, amount: UFix64) {
    let payment: @FlowToken.Vault
    let buyer: Address

    prepare(signer: auth(BorrowValue) &Account) {
        let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FlowToken vault")
        self.payment <- flowVault.withdraw(amount: amount) as! @FlowToken.Vault
        self.buyer = signer.address
    }

    execute {
        let poolRef = CoinFlip.borrowPool(id: id)
        poolRef.betOnHead(_addr: self.buyer, poolId: id, amount: <- self.payment)
    }
}

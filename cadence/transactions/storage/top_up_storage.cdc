// Top up a player's account with FLOW to increase storage capacity.
// Called by the sponsor account before minting into a player account that is near capacity.
//
// Flow storage formula (approximate): capacity_bytes = flowBalance / storageMegabytePerFLOW
// storageMegabytePerFLOW = 10.0 (i.e., 1 FLOW = 10MB capacity)
// A typical NFT with metadata uses ~2KB.

import "FlowToken"
import "FungibleToken"

transaction(recipient: Address, amount: UFix64) {
    let vaultRef: auth(FungibleToken.Withdraw) &FlowToken.Vault

    prepare(sponsor: auth(BorrowValue) &Account) {
        self.vaultRef = sponsor.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("No FLOW vault in sponsor account")
    }

    execute {
        let payment <- self.vaultRef.withdraw(amount: amount)
        let receiverCap = getAccount(recipient).capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let receiver = receiverCap.borrow() ?? panic("No FLOW receiver for recipient")
        receiver.deposit(from: <-payment)
    }
}

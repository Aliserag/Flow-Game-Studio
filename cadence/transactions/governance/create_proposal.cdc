import "Governance"
import "GameToken"
import "FungibleToken"

transaction(title: String, description: String, actionType: String, actionPayload: String) {
    let proposerAddress: Address
    let voterBalance: UFix64

    prepare(signer: auth(BorrowValue) &Account) {
        self.proposerAddress = signer.address
        let vault = signer.storage.borrow<&{FungibleToken.Balance}>(from: GameToken.VaultStoragePath)
            ?? panic("No GameToken vault")
        self.voterBalance = vault.balance
    }

    execute {
        let id = Governance.createProposal(
            proposer: self.proposerAddress,
            title: title,
            description: description,
            actionType: actionType,
            actionPayload: actionPayload,
            voterBalance: self.voterBalance
        )
        log("Proposal created with ID: ".concat(id.toString()))
    }
}

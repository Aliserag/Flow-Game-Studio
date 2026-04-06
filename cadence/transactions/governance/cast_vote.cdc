import "Governance"
import "GameToken"
import "FungibleToken"

transaction(proposalId: UInt64, support: Bool) {
    let voterAddress: Address
    let voterBalance: UFix64

    prepare(signer: auth(BorrowValue) &Account) {
        self.voterAddress = signer.address
        let vault = signer.storage.borrow<&{FungibleToken.Balance}>(from: GameToken.VaultStoragePath)
            ?? panic("No GameToken vault — cannot vote without tokens")
        self.voterBalance = vault.balance
    }

    execute {
        Governance.castVote(
            proposalId: proposalId,
            voter: self.voterAddress,
            support: support,
            weight: self.voterBalance
        )
        log("Vote cast on proposal ".concat(proposalId.toString()).concat(support ? " YES" : " NO"))
    }
}

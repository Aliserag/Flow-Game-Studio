import "Governance"
import "GameToken"

transaction(proposalId: UInt64, totalSupply: UFix64) {
    let adminRef: auth(Governance.Executor) &Governance.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        // First finalize if needed
        Governance.finalizeProposal(proposalId: proposalId, totalSupply: totalSupply)

        self.adminRef = signer.storage.borrow<auth(Governance.Executor) &Governance.Admin>(
            from: Governance.AdminStoragePath
        ) ?? panic("No Governance.Admin in storage")
    }

    execute {
        self.adminRef.executeProposal(proposalId: proposalId)
        log("Proposal ".concat(proposalId.toString()).concat(" executed"))
    }
}

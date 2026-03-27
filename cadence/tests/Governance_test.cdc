import Test
import "Governance"
import "EmergencyPause"

access(all) fun testProposalLifecycle() {
    let admin = Test.getAccount(0x0000000000000001)
    Test.deployContract(name: "EmergencyPause", path: "../contracts/systems/EmergencyPause.cdc", arguments: [])
    Test.deployContract(name: "Governance", path: "../contracts/governance/Governance.cdc", arguments: [])

    // Create proposal
    let id = Governance.createProposal(
        proposer: admin.address,
        title: "Test Proposal",
        description: "Testing governance",
        actionType: "update_price",
        actionPayload: "{\"item\":\"sword\",\"price\":100}",
        voterBalance: 2000.0
    )
    Test.assertEqual(0 as UInt64, id)
    Test.assertEqual(1 as UInt64, Governance.nextProposalId)

    // Cast vote
    Governance.castVote(proposalId: 0, voter: admin.address, support: true, weight: 2000.0)

    let proposal = Governance.proposals[0]!
    Test.assertEqual(2000.0, proposal.yesVotes)
    Test.assertEqual(0.0, proposal.noVotes)
}

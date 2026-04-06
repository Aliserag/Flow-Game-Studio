// cadence/tests/Governance_test.cdc
import Test
import "Governance"
import "EmergencyPause"

access(all) let deployer = Test.getAccount(0x0000000000000007)

access(all) fun setup() {
    // 1. Deploy GameToken (required by Governance)
    let tokenErr = Test.deployContract(
        name: "GameToken",
        path: "../contracts/core/GameToken.cdc",
        arguments: ["Gold", "GOLD", UFix64(1_000_000_000.0)]
    )
    Test.expect(tokenErr, Test.beNil())

    // 2. Deploy EmergencyPause (required by Governance)
    let pauseErr = Test.deployContract(
        name: "EmergencyPause",
        path: "../contracts/systems/EmergencyPause.cdc",
        arguments: []
    )
    Test.expect(pauseErr, Test.beNil())

    // 3. Deploy Governance
    let govErr = Test.deployContract(
        name: "Governance",
        path: "../contracts/governance/Governance.cdc",
        arguments: []
    )
    Test.expect(govErr, Test.beNil())
}

access(all) fun testProposalLifecycle() {
    // Create proposal via inline transaction (avoids getCurrentBlock() slab error)
    // createProposal is access(all) — no prepare block / no authorizers needed
    let createTx = Test.Transaction(
        code: "import \"Governance\"\n"
            .concat("transaction(proposer: Address) {\n")
            .concat("    execute {\n")
            .concat("        let id = Governance.createProposal(\n")
            .concat("            proposer: proposer,\n")
            .concat("            title: \"Test Proposal\",\n")
            .concat("            description: \"Testing governance\",\n")
            .concat("            actionType: \"update_price\",\n")
            .concat("            actionPayload: \"{\\\"item\\\":\\\"sword\\\",\\\"price\\\":100}\",\n")
            .concat("            voterBalance: 2000.0\n")
            .concat("        )\n")
            .concat("        assert(id == 0, message: \"expected proposalId 0\")\n")
            .concat("    }\n")
            .concat("}"),
        authorizers: [],
        signers: [],
        arguments: [deployer.address]
    )
    Test.expect(Test.executeTransaction(createTx), Test.beSucceeded())

    // Verify nextProposalId incremented
    let nextIdResult = Test.executeScript(
        "import Governance from 0x0000000000000007\n"
            .concat("access(all) fun main(): UInt64 { return Governance.nextProposalId }"),
        []
    )
    Test.expect(nextIdResult, Test.beSucceeded())
    Test.assertEqual(UInt64(1), nextIdResult.returnValue! as! UInt64)

    // Cast vote via inline transaction (castVote is access(all) — no prepare needed)
    let voteTx = Test.Transaction(
        code: "import \"Governance\"\n"
            .concat("transaction(voter: Address) {\n")
            .concat("    execute {\n")
            .concat("        Governance.castVote(\n")
            .concat("            proposalId: 0,\n")
            .concat("            voter: voter,\n")
            .concat("            support: true,\n")
            .concat("            weight: 2000.0\n")
            .concat("        )\n")
            .concat("    }\n")
            .concat("}"),
        authorizers: [],
        signers: [],
        arguments: [deployer.address]
    )
    Test.expect(Test.executeTransaction(voteTx), Test.beSucceeded())

    // Verify yes votes via script
    let yesVotesResult = Test.executeScript(
        "import Governance from 0x0000000000000007\n"
            .concat("access(all) fun main(): UFix64 {\n")
            .concat("    return Governance.proposals[0]?.yesVotes ?? 0.0\n")
            .concat("}"),
        []
    )
    Test.expect(yesVotesResult, Test.beSucceeded())
    Test.assertEqual(UFix64(2000.0), yesVotesResult.returnValue! as! UFix64)

    // Verify no votes via script
    let noVotesResult = Test.executeScript(
        "import Governance from 0x0000000000000007\n"
            .concat("access(all) fun main(): UFix64 {\n")
            .concat("    return Governance.proposals[0]?.noVotes ?? 0.0\n")
            .concat("}"),
        []
    )
    Test.expect(noVotesResult, Test.beSucceeded())
    Test.assertEqual(UFix64(0.0), noVotesResult.returnValue! as! UFix64)
}

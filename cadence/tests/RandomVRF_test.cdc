// cadence/tests/RandomVRF_test.cdc
import Test
import "RandomVRF"

access(all) fun setup() {
    let err = Test.deployContract(
        name: "RandomVRF",
        path: "../contracts/systems/RandomVRF.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all) fun testContractDeployment() {
    // Read live state via script to avoid import-time snapshot
    let result = Test.executeScript(
        "import RandomVRF from 0x0000000000000007\naccess(all) fun main(): UInt64 { return RandomVRF.totalCommits }",
        []
    )
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual(result.returnValue! as! UInt64, UInt64(0))
}

access(all) fun testCommitPhase() {
    let player = Test.createAccount()
    let secret: UInt256 = 12345678901234567890
    let gameId: UInt64 = 1

    let tx = Test.Transaction(
        code: Test.readFile("../transactions/vrf/commit_move.cdc"),
        authorizers: [player.address],
        signers: [player],
        arguments: [secret, gameId]
    )
    let txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    // Read live state via script
    let result = Test.executeScript(
        "import RandomVRF from 0x0000000000000007\naccess(all) fun main(): UInt64 { return RandomVRF.totalCommits }",
        []
    )
    Test.expect(result, Test.beSucceeded())
    Test.assert(result.returnValue! as! UInt64 >= UInt64(1), message: "totalCommits should be >= 1 after commit")
}

access(all) fun testCommitStoresHash() {
    let player = Test.createAccount()
    let secret: UInt256 = 99999
    let gameId: UInt64 = 42

    let tx = Test.Transaction(
        code: Test.readFile("../transactions/vrf/commit_move.cdc"),
        authorizers: [player.address],
        signers: [player],
        arguments: [secret, gameId]
    )
    let _ = Test.executeTransaction(tx)

    // Verify via script that commit is stored
    let commitKey = player.address.toString().concat("-").concat(gameId.toString())
    let result = Test.executeScript(
        "import RandomVRF from 0x0000000000000007\naccess(all) fun main(key: String): Bool { return RandomVRF.getCommit(key: key) != nil }",
        [commitKey]
    )
    Test.expect(result, Test.beSucceeded())
    Test.assert(result.returnValue! as! Bool, message: "Commit should be stored")
}

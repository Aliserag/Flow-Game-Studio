// cadence/tests/RandomVRF_test.cdc
import Test
import "RandomVRF"

access(all) fun testContractDeployment() {
    Test.assert(RandomVRF.totalCommits == 0, message: "Should start at 0")
}

access(all) fun testCommitPhase() {
    let player = Test.createAccount()
    let secret: UInt256 = 12345678901234567890
    let gameId: UInt64 = 1

    let txResult = Test.executeTransaction(
        "../transactions/vrf/commit_move.cdc",
        [secret, gameId],
        player
    )
    Test.expect(txResult, Test.beSucceeded())
    Test.assertEqual(RandomVRF.totalCommits, UInt64(1))
}

access(all) fun testCommitStoresHash() {
    let player = Test.createAccount()
    let secret: UInt256 = 99999
    let gameId: UInt64 = 42

    let _ = Test.executeTransaction(
        "../transactions/vrf/commit_move.cdc",
        [secret, gameId],
        player
    )

    let commitKey = player.address.toString().concat("-").concat(gameId.toString())
    let commit = RandomVRF.getCommit(key: commitKey)
    Test.assert(commit != nil, message: "Commit should be stored")
}

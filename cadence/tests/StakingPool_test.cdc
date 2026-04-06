// cadence/tests/StakingPool_test.cdc
import Test
import "StakingPool"
import "EmergencyPause"

access(all) fun setup() {
    // 1. Deploy GameToken (required by StakingPool)
    let tokenErr = Test.deployContract(
        name: "GameToken",
        path: "../contracts/core/GameToken.cdc",
        arguments: ["Gold", "GOLD", UFix64(1_000_000_000.0)]
    )
    Test.expect(tokenErr, Test.beNil())

    // 2. Deploy EmergencyPause (required by StakingPool)
    let pauseErr = Test.deployContract(
        name: "EmergencyPause",
        path: "../contracts/systems/EmergencyPause.cdc",
        arguments: []
    )
    Test.expect(pauseErr, Test.beNil())

    // 3. Deploy StakingPool
    let poolErr = Test.deployContract(
        name: "StakingPool",
        path: "../contracts/systems/StakingPool.cdc",
        arguments: []
    )
    Test.expect(poolErr, Test.beNil())
}

access(all) fun testStakeAndRewards() {
    let admin = Test.getAccount(0x0000000000000007)

    // Initial state
    Test.assertEqual(0.0, StakingPool.totalStaked)
    Test.assertEqual(0.0, StakingPool.rewardIndex)

    // Pending rewards for non-staker should be 0
    Test.assertEqual(0.0, StakingPool.pendingRewards(staker: admin.address))
}

access(all) fun testUnstakeDelay() {
    // Verify unstakeDelayBlocks is set to expected value
    Test.assertEqual(14_000 as UInt64, StakingPool.unstakeDelayBlocks)
}

import Test
import "StakingPool"
import "EmergencyPause"

access(all) fun testStakeAndRewards() {
    let admin = Test.getAccount(0x0000000000000001)
    Test.deployContract(name: "EmergencyPause", path: "../contracts/systems/EmergencyPause.cdc", arguments: [])
    Test.deployContract(name: "StakingPool", path: "../contracts/systems/StakingPool.cdc", arguments: [])

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

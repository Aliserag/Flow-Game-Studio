import "StakingPool"

access(all) fun main(stakerAddress: Address): {String: AnyStruct} {
    let pending = StakingPool.pendingRewards(staker: stakerAddress)
    let info = StakingPool.stakers[stakerAddress]

    return {
        "stakedAmount": info?.stakedAmount ?? 0.0,
        "pendingRewards": pending,
        "unstakeRequestBlock": info?.unstakeRequestBlock ?? 0,
        "unstakeAmount": info?.unstakeAmount ?? 0.0,
        "totalStaked": StakingPool.totalStaked,
        "rewardIndex": StakingPool.rewardIndex
    }
}

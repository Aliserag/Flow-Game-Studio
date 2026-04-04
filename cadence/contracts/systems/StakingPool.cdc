// StakingPool.cdc
// Players stake GameToken and earn proportional yield from Marketplace fees.
//
// Reward model: Index-based accumulator (avoids iterating all stakers)
// - rewardIndex: accumulated rewards per staked token since launch
// - stakerIndex[address]: rewardIndex snapshot at last stake/claim
// - pendingReward(address) = (rewardIndex - stakerIndex[address]) * stakedAmount
//
// Unstaking delay: 14 epochs (~3.5 days at 1000 blocks/epoch) prevents
// stake-to-claim-and-exit attacks on freshly deposited rewards.

import "FungibleToken"
import "GameToken"
import "EmergencyPause"

access(all) contract StakingPool {

    access(all) entitlement StakingAdmin
    access(all) entitlement StakerAccess

    access(all) struct StakerInfo {
        access(all) var stakedAmount: UFix64
        access(all) var rewardIndexSnapshot: UFix64  // rewardIndex at last stake/claim
        access(all) var unstakeRequestBlock: UInt64  // 0 = no pending unstake
        access(all) var unstakeAmount: UFix64

        access(contract) fun setStakedAmount(_ v: UFix64) { self.stakedAmount = v }
        access(contract) fun setRewardIndexSnapshot(_ v: UFix64) { self.rewardIndexSnapshot = v }
        access(contract) fun setUnstakeRequestBlock(_ v: UInt64) { self.unstakeRequestBlock = v }
        access(contract) fun setUnstakeAmount(_ v: UFix64) { self.unstakeAmount = v }

        init() {
            self.stakedAmount = 0.0
            self.rewardIndexSnapshot = 0.0
            self.unstakeRequestBlock = 0
            self.unstakeAmount = 0.0
        }
    }

    // Global state
    access(all) var totalStaked: UFix64
    access(all) var rewardIndex: UFix64        // accumulated rewards per token staked
    access(all) var rewardReserve: UFix64      // undistributed rewards in the pool
    access(all) var stakers: {Address: StakerInfo}
    access(all) var unstakeDelayBlocks: UInt64  // default: 14 * 1000 = 14,000 blocks

    access(all) let VaultStoragePath: StoragePath  // pool's GameToken vault
    access(all) let AdminStoragePath: StoragePath

    access(all) event Staked(staker: Address, amount: UFix64, total: UFix64)
    access(all) event UnstakeRequested(staker: Address, amount: UFix64, readyAtBlock: UInt64)
    access(all) event Unstaked(staker: Address, amount: UFix64)
    access(all) event RewardsClaimed(staker: Address, amount: UFix64)
    access(all) event RewardsDistributed(amount: UFix64, newIndex: UFix64)

    // Calculate pending rewards without mutating state
    access(all) fun pendingRewards(staker: Address): UFix64 {
        if StakingPool.stakers[staker] == nil { return 0.0 }
        let info = StakingPool.stakers[staker]!
        if info.stakedAmount == 0.0 { return 0.0 }
        let indexDelta = StakingPool.rewardIndex - info.rewardIndexSnapshot
        return indexDelta * info.stakedAmount
    }

    // Stake tokens
    access(all) fun stake(staker: Address, payment: @{FungibleToken.Vault}) {
        pre { payment.balance > 0.0: "Cannot stake 0 tokens" }
        EmergencyPause.assertNotPaused()

        let amount = payment.balance

        // Settle pending rewards before changing staked amount
        if StakingPool.stakers[staker] == nil {
            StakingPool.stakers[staker] = StakerInfo()
        }
        var info = StakingPool.stakers[staker]!
        if info.stakedAmount > 0.0 {
            let pending = (StakingPool.rewardIndex - info.rewardIndexSnapshot) * info.stakedAmount
            StakingPool.rewardReserve = StakingPool.rewardReserve + pending
        }

        info.setStakedAmount(info.stakedAmount + amount)
        info.setRewardIndexSnapshot(StakingPool.rewardIndex)
        StakingPool.stakers[staker] = info
        StakingPool.totalStaked = StakingPool.totalStaked + amount

        // Deposit tokens into pool vault
        let vault = StakingPool.account.storage.borrow<&{FungibleToken.Receiver}>(
            from: StakingPool.VaultStoragePath
        )!
        vault.deposit(from: <-payment)

        emit Staked(staker: staker, amount: amount, total: StakingPool.totalStaked)
    }

    // Request unstake (starts delay timer)
    access(all) fun requestUnstake(staker: Address, amount: UFix64) {
        pre {
            StakingPool.stakers[staker] != nil: "Not staking"
        }
        EmergencyPause.assertNotPaused()
        var info = StakingPool.stakers[staker]!
        assert(info.stakedAmount >= amount, message: "Insufficient staked balance")
        assert(info.unstakeRequestBlock == 0, message: "Unstake already pending — wait for it to complete")

        // Settle pending rewards first
        let pending = (StakingPool.rewardIndex - info.rewardIndexSnapshot) * info.stakedAmount
        if pending > 0.0 {
            StakingPool.rewardReserve = StakingPool.rewardReserve + pending
        }

        info.setUnstakeRequestBlock(getCurrentBlock().height)
        info.setUnstakeAmount(amount)
        info.setRewardIndexSnapshot(StakingPool.rewardIndex)
        StakingPool.stakers[staker] = info

        emit UnstakeRequested(
            staker: staker,
            amount: amount,
            readyAtBlock: getCurrentBlock().height + StakingPool.unstakeDelayBlocks
        )
    }

    // Complete unstake after delay
    access(all) fun completeUnstake(
        staker: Address,
        receiver: &{FungibleToken.Receiver}
    ) {
        pre {
            StakingPool.stakers[staker] != nil: "Not staking"
        }
        EmergencyPause.assertNotPaused()
        var info = StakingPool.stakers[staker]!
        assert(info.unstakeRequestBlock > 0, message: "No pending unstake")
        assert(getCurrentBlock().height >= info.unstakeRequestBlock + StakingPool.unstakeDelayBlocks,
            message: "Unstake delay not elapsed")

        let amount = info.unstakeAmount
        info.setStakedAmount(info.stakedAmount - amount)
        info.setUnstakeRequestBlock(0)
        info.setUnstakeAmount(0.0)
        StakingPool.stakers[staker] = info
        StakingPool.totalStaked = StakingPool.totalStaked - amount

        // Withdraw from pool vault
        let vault = StakingPool.account.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(
            from: StakingPool.VaultStoragePath
        )!
        let tokens <- vault.withdraw(amount: amount)
        receiver.deposit(from: <-tokens)

        emit Unstaked(staker: staker, amount: amount)
    }

    // Claim accumulated rewards
    access(all) fun claimRewards(staker: Address, receiver: &{FungibleToken.Receiver}) {
        EmergencyPause.assertNotPaused()
        var info = StakingPool.stakers[staker] ?? panic("Not staking")
        let pending = (StakingPool.rewardIndex - info.rewardIndexSnapshot) * info.stakedAmount
        assert(pending > 0.0, message: "No rewards to claim")

        info.setRewardIndexSnapshot(StakingPool.rewardIndex)
        StakingPool.stakers[staker] = info
        StakingPool.rewardReserve = StakingPool.rewardReserve - pending

        let vault = StakingPool.account.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(
            from: StakingPool.VaultStoragePath
        )!
        let tokens <- vault.withdraw(amount: pending)
        receiver.deposit(from: <-tokens)

        emit RewardsClaimed(staker: staker, amount: pending)
    }

    access(all) resource Admin {
        // Called by Marketplace (or admin) to distribute platform fee revenue to stakers
        access(StakingAdmin) fun distributeRewards(payment: @{FungibleToken.Vault}) {
            pre { StakingPool.totalStaked > 0.0 : "No stakers" }
            let amount = payment.balance

            // Update the global reward index: each staked token earns amount/totalStaked
            let indexIncrease = amount / StakingPool.totalStaked
            StakingPool.rewardIndex = StakingPool.rewardIndex + indexIncrease

            let vault = StakingPool.account.storage.borrow<&{FungibleToken.Receiver}>(
                from: StakingPool.VaultStoragePath
            )!
            vault.deposit(from: <-payment)

            emit RewardsDistributed(amount: amount, newIndex: StakingPool.rewardIndex)
        }
    }

    init() {
        self.totalStaked = 0.0
        self.rewardIndex = 0.0
        self.rewardReserve = 0.0
        self.stakers = {}
        self.unstakeDelayBlocks = 14_000   // ~14 epochs

        self.VaultStoragePath = /storage/StakingPoolVault
        self.AdminStoragePath = /storage/StakingPoolAdmin

        // Create empty vault for receiving staked tokens
        self.account.storage.save(
            <-GameToken.createEmptyVault(vaultType: Type<@GameToken.Vault>()),
            to: self.VaultStoragePath
        )
        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}

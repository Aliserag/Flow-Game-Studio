import FungibleToken from 0xFungibleToken
import FlowToken from 0xFlowToken

/// CoinFlip — YOLO betting pool on Flow blockchain
///
/// Users bet FLOW tokens on HEAD or TAIL in time-limited pools.
/// After endTime, admin tosses using revertibleRandom(), losers' tokens
/// go to pool vault, winners claim proportional share + original bet.
access(all) contract CoinFlip {

    // ========================================================================
    // EVENTS
    // ========================================================================
    access(all) event BetOnHead(id: UInt64, address: Address, amount: UFix64)
    access(all) event BetOnTail(id: UInt64, address: Address, amount: UFix64)
    access(all) event NewPoolCreated(id: UInt64)
    access(all) event RewardClaimed(id: UInt64, address: Address, amount: UFix64)
    access(all) event ContractInitialized()

    // ========================================================================
    // STATE
    // ========================================================================
    access(all) var totalPools: UInt64

    /// Entitlement required to update winning share calculations
    access(all) entitlement UpdateWinnings

    access(all) enum PoolStatus: UInt8 {
        access(all) case OPEN
        access(all) case CALCULATING
        access(all) case CLOSE
    }

    // ========================================================================
    // USER STRUCTS
    // ========================================================================
    access(all) struct HeadBet_User {
        access(all) let choice: String
        access(all) let bet_amount: UFix64
        access(all) var claim_amount: UFix64
        access(all) var rewardClaimed: Bool

        init(_choise: String, b_amount: UFix64) {
            self.choice = _choise
            self.bet_amount = b_amount
            self.claim_amount = 0.0
            self.rewardClaimed = false
        }

        access(all) fun setClaimAmount(newAmount: UFix64) {
            self.claim_amount = newAmount
        }

        access(all) fun setRewardClaimed(newValue: Bool) {
            self.rewardClaimed = newValue
        }
    }

    access(all) struct TailBet_User {
        access(all) let choice: String
        access(all) let bet_amount: UFix64
        access(all) var claim_amount: UFix64
        access(all) var rewardClaimed: Bool

        init(_choise: String, b_amount: UFix64) {
            self.choice = _choise
            self.bet_amount = b_amount
            self.claim_amount = 0.0
            self.rewardClaimed = false
        }

        access(all) fun setClaimAmount(newAmount: UFix64) {
            self.claim_amount = newAmount
        }

        access(all) fun setRewardClaimed(newValue: Bool) {
            self.rewardClaimed = newValue
        }
    }

    // ========================================================================
    // POOL RESOURCE
    // ========================================================================
    access(all) resource Pool {
        access(all) let id: UInt64
        access(all) var status: PoolStatus
        access(all) var headInfo: {Address: CoinFlip.HeadBet_User}
        access(all) var tailInfo: {Address: CoinFlip.TailBet_User}
        access(mapping Identity) let headVault: @FlowToken.Vault
        access(mapping Identity) let tailVault: @FlowToken.Vault
        access(mapping Identity) let poolVault: @FlowToken.Vault
        access(all) var startTime: UFix64
        access(all) var endTime: UFix64
        access(all) var tossResult: String
        access(all) var coinFlipped: Bool
        access(all) var h_winningShare: {Address: UFix64}
        access(all) var t_winningShare: {Address: UFix64}

        init() {
            self.id = CoinFlip.totalPools
            self.status = PoolStatus.OPEN
            self.headInfo = {}
            self.tailInfo = {}
            self.headVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
            self.tailVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
            self.poolVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
            self.startTime = getCurrentBlock().timestamp
            // 300 seconds (5 min) for emulator demos; 86400 for production
            self.endTime = self.startTime + 300.0
            self.tossResult = ""
            self.coinFlipped = false
            self.h_winningShare = {}
            self.t_winningShare = {}
        }

        access(all) view fun getStatus(): PoolStatus {
            return self.status
        }

        access(all) view fun getHeadBetUserInfo(addr: Address): &CoinFlip.HeadBet_User {
            return &self.headInfo[addr]!
        }

        access(all) view fun getTailBetUserInfo(_addr: Address): &CoinFlip.TailBet_User {
            return &self.tailInfo[_addr]!
        }

        access(CoinFlip.UpdateWinnings) fun set_h_winningShare(address: Address, newValue: UFix64) {
            self.h_winningShare[address] = newValue
        }

        access(CoinFlip.UpdateWinnings) fun set_t_winningShare(address: Address, newValue: UFix64) {
            self.t_winningShare[address] = newValue
        }

        access(all) fun setTossResult(newValue: String) {
            self.tossResult = newValue
        }

        access(all) fun setCoinFlipped(newValue: Bool) {
            self.coinFlipped = newValue
        }

        access(all) fun setStatus(newValue: CoinFlip.PoolStatus) {
            self.status = newValue
        }

        access(all) view fun getTailBalance(): UFix64 {
            let a = self.tailInfo
            let b = a.keys
            let c = a.length
            var i = 0
            var sum = 0.0
            while i < c {
                let d = a[b[i]]?.bet_amount!
                sum = sum + d
                i = i + 1
            }
            return sum
        }

        access(all) view fun getHeadBalance(): UFix64 {
            let a = self.headInfo
            let b = a.keys
            let c = a.length
            var i = 0
            var sum = 0.0
            while i < c {
                let d = a[b[i]]?.bet_amount!
                sum = sum + d
                i = i + 1
            }
            return sum
        }

        access(all) view fun getPoolTotalBalance(): UFix64 {
            return self.getHeadBalance() + self.getTailBalance()
        }

        access(all) fun betOnHead(_addr: Address, poolId: UInt64, amount: @FlowToken.Vault) {
            pre {
                amount.balance == UFix64(UInt64(amount.balance)): "Bet must be a whole number of FLOW"
                amount.balance > 0.0: "Bet amount cannot be zero"
                getCurrentBlock().timestamp <= self.endTime: "Pool betting window has closed"
                self.status == PoolStatus.OPEN: "Pool is not open"
            }
            let betAmount: UFix64 = UFix64(UInt64(amount.balance))
            self.headVault.deposit(from: <- amount)
            if self.headInfo[_addr] == nil {
                self.headInfo[_addr] = CoinFlip.HeadBet_User(_choise: "HEAD", b_amount: betAmount)
            } else {
                let pre_amount = self.getHeadBetUserInfo(addr: _addr).bet_amount
                self.headInfo[_addr] = CoinFlip.HeadBet_User(_choise: "HEAD", b_amount: pre_amount + betAmount)
            }
            emit BetOnHead(id: poolId, address: _addr, amount: betAmount)
        }

        access(all) fun betOnTail(_addr: Address, poolId: UInt64, amount: @FlowToken.Vault) {
            pre {
                amount.balance == UFix64(UInt64(amount.balance)): "Bet must be a whole number of FLOW"
                amount.balance > 0.0: "Bet amount cannot be zero"
                getCurrentBlock().timestamp <= self.endTime: "Pool betting window has closed"
                self.status == PoolStatus.OPEN: "Pool is not open"
            }
            let betAmount = UFix64(UInt64(amount.balance))
            self.tailVault.deposit(from: <- amount)
            if self.tailInfo[_addr] == nil {
                self.tailInfo[_addr] = CoinFlip.TailBet_User(_choise: "TAIL", b_amount: betAmount)
            } else {
                let pre_amount = self.getTailBetUserInfo(_addr: _addr).bet_amount
                self.tailInfo[_addr] = CoinFlip.TailBet_User(_choise: "TAIL", b_amount: pre_amount + betAmount)
            }
            emit BetOnTail(id: poolId, address: _addr, amount: betAmount)
        }
    }

    // ========================================================================
    // ADMIN RESOURCE — stored at /storage/CoinFlipGameManager
    // ========================================================================
    access(all) resource Admin {
        access(all) let ownedPools: @{UInt64: Pool}

        access(contract) fun createPool() {
            CoinFlip.totalPools = CoinFlip.totalPools + 1
            let newPool <- create Pool()
            self.ownedPools[newPool.id] <-! newPool
            emit NewPoolCreated(id: CoinFlip.totalPools)
        }

        access(all) view fun borrowPool(id: UInt64): &Pool? {
            return &self.ownedPools[id]
        }

        access(all) view fun borrowEntitlementPool(id: UInt64): auth(CoinFlip.UpdateWinnings) &Pool? {
            return (&self.ownedPools[id] as auth(CoinFlip.UpdateWinnings) &Pool?)!
        }

        access(all) view fun borrowWithdrawEntitlement(id: UInt64): auth(FungibleToken.Withdraw) &Pool? {
            return (&self.ownedPools[id] as auth(FungibleToken.Withdraw) &Pool?)!
        }

        access(all) view fun getPoolIDs(): [UInt64] {
            return self.ownedPools.keys
        }

        access(all) view fun isCoinFlipped(id: UInt64): Bool {
            let poolRef = self.borrowPool(id: id) ?? panic("Pool not found")
            return poolRef.coinFlipped
        }

        access(all) view fun poolEndTime(id: UInt64): UFix64 {
            let poolRef = self.borrowPool(id: id) ?? panic("Pool not found")
            return poolRef.endTime
        }

        access(contract) fun headUsersWinningShare(id: UInt64) {
            let poolRef = self.borrowEntitlementPool(id: id) ?? panic("Pool not found")
            let totalBalance = poolRef.headVault.balance
            let keys = poolRef.headInfo.keys
            var i = 0
            while i < poolRef.headInfo.length {
                let address = keys[i]
                let betAmount = poolRef.getHeadBetUserInfo(addr: address).bet_amount
                poolRef.set_h_winningShare(address: address, newValue: (betAmount / totalBalance) * 100.0)
                i = i + 1
            }
        }

        access(contract) fun tailUsersWinningShare(id: UInt64) {
            let poolRef = self.borrowEntitlementPool(id: id) ?? panic("Pool not found")
            let totalBalance = poolRef.tailVault.balance
            let keys = poolRef.tailInfo.keys
            var i = 0
            while i < poolRef.tailInfo.length {
                let address = keys[i]
                let betAmount = poolRef.getTailBetUserInfo(_addr: address).bet_amount
                poolRef.set_t_winningShare(address: address, newValue: (betAmount / totalBalance) * 100.0)
                i = i + 1
            }
        }

        access(all) fun tossCoin(id: UInt64) {
            pre {
                !self.isCoinFlipped(id: id): "Coin already flipped for this pool"
                getCurrentBlock().timestamp >= self.poolEndTime(id: id): "Pool betting window not ended yet"
            }

            let poolRef = self.borrowPool(id: id) ?? panic("Pool not found")
            let tokenPoolRef = self.borrowWithdrawEntitlement(id: id) ?? panic("Pool not found")

            let randomNumber: UInt64 = CoinFlip.getRandom(min: 1, max: 2)

            if randomNumber == 1 {
                poolRef.setTossResult(newValue: "HEAD")
                self.headUsersWinningShare(id: id)
                let balance = poolRef.tailVault.balance
                let rewards: @FlowToken.Vault <- tokenPoolRef.tailVault.withdraw(amount: balance) as! @FlowToken.Vault
                poolRef.poolVault.deposit(from: <- rewards)
                CoinFlip.headClaimReward(poolId: id)
            } else {
                poolRef.setTossResult(newValue: "TAIL")
                self.tailUsersWinningShare(id: id)
                let balance = poolRef.headVault.balance
                let rewards <- tokenPoolRef.headVault.withdraw(amount: balance) as! @FlowToken.Vault
                poolRef.poolVault.deposit(from: <- rewards)
                CoinFlip.tailClaimReward(poolId: id)
            }
            self.createPool()
        }

        init() {
            self.ownedPools <- {}
        }
    }

    // ========================================================================
    // INTERNAL HELPERS — called by tossCoin after result determined
    // ========================================================================
    access(contract) fun headClaimReward(poolId: UInt64) {
        let poolRef = self.borrowPool(id: poolId)
        for addr in poolRef.headInfo.keys {
            let user = poolRef.getHeadBetUserInfo(addr: addr)
            let betAmount = user.bet_amount
            let share = poolRef.h_winningShare[addr]!
            let reward = poolRef.getTailBalance() * share / 100.0
            user.setClaimAmount(newAmount: betAmount + reward)
        }
        poolRef.setCoinFlipped(newValue: true)
        poolRef.setStatus(newValue: PoolStatus.CLOSE)
    }

    access(contract) fun tailClaimReward(poolId: UInt64) {
        let poolRef = self.borrowPool(id: poolId)
        for addr in poolRef.tailInfo.keys {
            let user = poolRef.getTailBetUserInfo(_addr: addr)
            let betAmount = user.bet_amount
            let share = poolRef.t_winningShare[addr]!
            let reward = poolRef.getHeadBalance() * share / 100.0
            user.setClaimAmount(newAmount: betAmount + reward)
        }
        poolRef.setCoinFlipped(newValue: true)
        poolRef.setStatus(newValue: PoolStatus.CLOSE)
    }

    // ========================================================================
    // PUBLIC RANDOMNESS
    // ========================================================================
    access(all) fun getRandom(min: UInt64, max: UInt64): UInt64 {
        let rand: UInt64 = revertibleRandom<UInt64>(modulo: UInt64.max)
        return (rand % (max + 1 - min)) + min
    }

    // ========================================================================
    // PUBLIC ACCESSORS
    // ========================================================================
    access(all) view fun borrowAdmin(): &Admin {
        return self.account.storage.borrow<&CoinFlip.Admin>(from: /storage/CoinFlipGameManager)!
    }

    access(all) view fun borrowPool(id: UInt64): &Pool {
        return self.borrowAdmin().borrowPool(id: id) ?? panic("Pool not found: ".concat(id.toString()))
    }

    access(all) view fun borrowWithdrawEntitlement(id: UInt64): auth(FungibleToken.Withdraw) &CoinFlip.Pool {
        return self.borrowAdmin().borrowWithdrawEntitlement(id: id) ?? panic("Pool not found: ".concat(id.toString()))
    }

    access(all) view fun getAllPoolId(): [UInt64] {
        return self.borrowAdmin().getPoolIDs()
    }

    // ========================================================================
    // CLAIM REWARD — called by winners after tossCoin
    // ========================================================================
    access(all) fun claimReward(poolId: UInt64, userAddress: Address) {
        pre {
            getCurrentBlock().timestamp >= self.borrowPool(id: poolId).endTime: "Pool still open"
            self.borrowPool(id: poolId).coinFlipped: "Coin not tossed yet"
            self.borrowPool(id: poolId).headInfo[userAddress] != nil ||
                self.borrowPool(id: poolId).tailInfo[userAddress] != nil: "You did not participate"
            self.borrowPool(id: poolId).headInfo[userAddress]?.choice == self.borrowPool(id: poolId).tossResult ||
                self.borrowPool(id: poolId).tailInfo[userAddress]?.choice == self.borrowPool(id: poolId).tossResult: "You lost — better luck next pool"
            // FIX: check rewardClaimed for the correct side (head OR tail bettor)
            (self.borrowPool(id: poolId).headInfo[userAddress]?.rewardClaimed ?? false) == false &&
                (self.borrowPool(id: poolId).tailInfo[userAddress]?.rewardClaimed ?? false) == false: "Reward already claimed"
        }

        let result = self.borrowPool(id: poolId).tossResult

        if result == "HEAD" {
            let poolRef = self.borrowPool(id: poolId)
            let poolWithdrawRef = self.borrowWithdrawEntitlement(id: poolId)
            let user = poolRef.getHeadBetUserInfo(addr: userAddress)
            let user_betAmount = user.bet_amount
            let claim_amount = user.claim_amount
            let reward_amount = claim_amount - user_betAmount
            user.setRewardClaimed(newValue: true)

            let bet_amount <- poolWithdrawRef.headVault.withdraw(amount: user_betAmount) as! @FlowToken.Vault
            let reward <- poolWithdrawRef.poolVault.withdraw(amount: reward_amount) as! @FlowToken.Vault

            if reward.balance > 0.0 {
                let platformFee_fromBet <- bet_amount.withdraw(amount: bet_amount.balance * 0.01) as! @FlowToken.Vault
                let platformFee_fromReward <- reward.withdraw(amount: reward.balance * 0.01) as! @FlowToken.Vault
                let platformVault = CoinFlip.account.capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                    ?? panic("Could not borrow platform vault receiver")
                platformVault.deposit(from: <- platformFee_fromBet)
                platformVault.deposit(from: <- platformFee_fromReward)
            }

            let userReceiver = getAccount(userAddress).capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                ?? panic("User does not have a Flow Token receiver set up")
            userReceiver.deposit(from: <- bet_amount)
            userReceiver.deposit(from: <- reward)
            emit RewardClaimed(id: poolId, address: userAddress, amount: claim_amount)

        } else {
            let poolRef = self.borrowPool(id: poolId)
            let poolWithdrawRef = self.borrowWithdrawEntitlement(id: poolId)
            let user = poolRef.getTailBetUserInfo(_addr: userAddress)
            let user_betAmount = user.bet_amount
            let claim_amount = user.claim_amount
            let reward_amount = claim_amount - user_betAmount
            user.setRewardClaimed(newValue: true)

            let bet_amount <- poolWithdrawRef.tailVault.withdraw(amount: user_betAmount) as! @FlowToken.Vault
            let reward <- poolWithdrawRef.poolVault.withdraw(amount: reward_amount) as! @FlowToken.Vault

            if reward.balance > 0.0 {
                let platformFee_fromBet <- bet_amount.withdraw(amount: bet_amount.balance * 0.01) as! @FlowToken.Vault
                let platformFee_fromReward <- reward.withdraw(amount: reward.balance * 0.01) as! @FlowToken.Vault
                let platformVault = CoinFlip.account.capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                    ?? panic("Could not borrow platform vault receiver")
                platformVault.deposit(from: <- platformFee_fromBet)
                platformVault.deposit(from: <- platformFee_fromReward)
            }

            let userReceiver = getAccount(userAddress).capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                ?? panic("User does not have a Flow Token receiver set up")
            userReceiver.deposit(from: <- bet_amount)
            userReceiver.deposit(from: <- reward)
            emit RewardClaimed(id: poolId, address: userAddress, amount: claim_amount)
        }
    }

    // ========================================================================
    // INIT
    // ========================================================================
    init() {
        self.totalPools = 0
        let admin: @Admin <- create Admin()
        admin.createPool()
        self.account.storage.save(<- admin, to: /storage/CoinFlipGameManager)
        emit ContractInitialized()
    }
}

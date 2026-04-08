import "FungibleToken"
import "FlowToken"
import "RandomBeaconHistory"

/// CoinFlip — YOLO betting pool on Flow blockchain
///
/// Users bet FLOW tokens on HEAD or TAIL in time-limited pools.
/// After endTime, admin commits the toss in one transaction, then reveals
/// in a second transaction using RandomBeaconHistory for non-revertible
/// randomness. Winners claim proportional share + original bet.
///
/// Security model:
/// - Admin resource never leaves /storage/CoinFlipGameManager; no public borrow.
/// - All Pool state mutations use access(contract) — external code gets read-only views.
/// - Randomness uses commit/reveal via RandomBeaconHistory (non-revertible).
/// - Withdrawal entitlements never exposed publicly.
access(all) contract CoinFlip {

    // ========================================================================
    // EVENTS
    // ========================================================================
    access(all) event BetOnHead(id: UInt64, address: Address, amount: UFix64)
    access(all) event BetOnTail(id: UInt64, address: Address, amount: UFix64)
    access(all) event NewPoolCreated(id: UInt64)
    access(all) event TossCommitted(id: UInt64, atBlockHeight: UInt64)
    access(all) event RewardClaimed(id: UInt64, address: Address, amount: UFix64)
    access(all) event ContractInitialized()

    // ========================================================================
    // STATE
    // ========================================================================
    access(all) var totalPools: UInt64

    /// Entitlement required to update winning share calculations.
    access(all) entitlement UpdateWinnings

    access(all) enum PoolStatus: UInt8 {
        access(all) case OPEN
        access(all) case CALCULATING
        access(all) case CLOSE
    }

    // ========================================================================
    // USER STRUCTS
    // ========================================================================

    /// Represents a user's HEAD bet. Setters are access(contract) to prevent
    /// external callers from inflating claim amounts or resetting claim flags.
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

        /// Only callable from within the CoinFlip contract.
        access(contract) fun setClaimAmount(newAmount: UFix64) {
            self.claim_amount = newAmount
        }

        /// Only callable from within the CoinFlip contract.
        access(contract) fun setRewardClaimed(newValue: Bool) {
            self.rewardClaimed = newValue
        }
    }

    /// Represents a user's TAIL bet. Same access rules as HeadBet_User.
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

        /// Only callable from within the CoinFlip contract.
        access(contract) fun setClaimAmount(newAmount: UFix64) {
            self.claim_amount = newAmount
        }

        /// Only callable from within the CoinFlip contract.
        access(contract) fun setRewardClaimed(newValue: Bool) {
            self.rewardClaimed = newValue
        }
    }

    // ========================================================================
    // POOL RESOURCE
    // ========================================================================
    access(all) resource Pool {
        access(all) let id: UInt64

        /// Pool open/close/calculating state. access(contract) prevents external
        /// code from reopening a closed pool or skipping the CALCULATING phase.
        access(contract) var status: PoolStatus

        /// Bet registries — readable for scripts, writable only via betOnHead/betOnTail.
        access(all) var headInfo: {Address: CoinFlip.HeadBet_User}
        access(all) var tailInfo: {Address: CoinFlip.TailBet_User}

        access(mapping Identity) let headVault: @FlowToken.Vault
        access(mapping Identity) let tailVault: @FlowToken.Vault
        access(mapping Identity) let poolVault: @FlowToken.Vault

        /// Immutable timing — set once in init, never changed.
        access(all) let startTime: UFix64
        access(all) let endTime: UFix64

        /// Toss outcome fields — access(contract) prevents external manipulation.
        access(contract) var tossResult: String
        access(contract) var coinFlipped: Bool

        /// Block height committed by the admin for randomness reveal.
        /// nil until commitToss() is called.
        access(contract) var committedBlockHeight: UInt64?

        access(CoinFlip.UpdateWinnings) var h_winningShare: {Address: UFix64}
        access(CoinFlip.UpdateWinnings) var t_winningShare: {Address: UFix64}

        init() {
            self.id = CoinFlip.totalPools
            self.status = PoolStatus.OPEN
            self.headInfo = {}
            self.tailInfo = {}
            self.headVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
            self.tailVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
            self.poolVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>())
            self.startTime = getCurrentBlock().timestamp
            // 60 seconds for testing; 3600 for testnet; 86400 for mainnet
            self.endTime = self.startTime + 60.0
            self.tossResult = ""
            self.coinFlipped = false
            self.committedBlockHeight = nil
            self.h_winningShare = {}
            self.t_winningShare = {}
        }

        // ── Read-only getters (safe for all callers via &Pool) ────────────

        /// Current pool status.
        access(all) view fun getStatus(): PoolStatus {
            return self.status
        }

        /// Result of the coin toss ("" | "HEAD" | "TAIL").
        access(all) view fun getTossResult(): String {
            return self.tossResult
        }

        /// Whether the coin has been flipped for this pool.
        access(all) view fun isCoinFlipped(): Bool {
            return self.coinFlipped
        }

        /// Block height committed for randomness (nil until commitToss called).
        access(all) view fun getCommittedHeight(): UInt64? {
            return self.committedBlockHeight
        }

        /// Whether a given address has a head bet.
        access(all) view fun hasHeadBet(addr: Address): Bool {
            return self.headInfo[addr] != nil
        }

        /// Whether a given address has a tail bet.
        access(all) view fun hasTailBet(addr: Address): Bool {
            return self.tailInfo[addr] != nil
        }

        access(all) view fun getHeadBetUserInfo(addr: Address): &CoinFlip.HeadBet_User {
            return &self.headInfo[addr]!
        }

        access(all) view fun getTailBetUserInfo(_addr: Address): &CoinFlip.TailBet_User {
            return &self.tailInfo[_addr]!
        }

        /// Winning share for a head bettor (nil if not set yet).
        access(all) view fun getHWinningShare(address: Address): UFix64? {
            return self.h_winningShare[address]
        }

        /// Winning share for a tail bettor (nil if not set yet).
        access(all) view fun getTWinningShare(address: Address): UFix64? {
            return self.t_winningShare[address]
        }

        // ── Entitlement-gated setters ─────────────────────────────────────

        access(CoinFlip.UpdateWinnings) fun set_h_winningShare(address: Address, newValue: UFix64) {
            self.h_winningShare[address] = newValue
        }

        access(CoinFlip.UpdateWinnings) fun set_t_winningShare(address: Address, newValue: UFix64) {
            self.t_winningShare[address] = newValue
        }

        // ── Contract-only mutation ────────────────────────────────────────

        /// Fires when admin calls commitToss or tossCoin.
        access(contract) fun setTossResult(newValue: String) {
            self.tossResult = newValue
        }

        access(contract) fun setCoinFlipped(newValue: Bool) {
            self.coinFlipped = newValue
        }

        access(contract) fun setStatus(newValue: CoinFlip.PoolStatus) {
            self.status = newValue
        }

        access(contract) fun setCommittedHeight(newValue: UInt64) {
            self.committedBlockHeight = newValue
        }

        // ── Balance helpers ───────────────────────────────────────────────

        access(all) view fun getTailBalance(): UFix64 {
            var sum = 0.0
            for key in self.tailInfo.keys {
                sum = sum + (self.tailInfo[key]?.bet_amount ?? 0.0)
            }
            return sum
        }

        access(all) view fun getHeadBalance(): UFix64 {
            var sum = 0.0
            for key in self.headInfo.keys {
                sum = sum + (self.headInfo[key]?.bet_amount ?? 0.0)
            }
            return sum
        }

        access(all) view fun getPoolTotalBalance(): UFix64 {
            return self.getHeadBalance() + self.getTailBalance()
        }

        // ── Betting ───────────────────────────────────────────────────────

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
                let preAmount = self.getHeadBetUserInfo(addr: _addr).bet_amount
                self.headInfo[_addr] = CoinFlip.HeadBet_User(_choise: "HEAD", b_amount: preAmount + betAmount)
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
                let preAmount = self.getTailBetUserInfo(_addr: _addr).bet_amount
                self.tailInfo[_addr] = CoinFlip.TailBet_User(_choise: "TAIL", b_amount: preAmount + betAmount)
            }
            emit BetOnTail(id: poolId, address: _addr, amount: betAmount)
        }
    }

    // ========================================================================
    // ADMIN RESOURCE — stored at /storage/CoinFlipGameManager
    // NEVER published or exposed via a public borrow function.
    // ========================================================================
    access(all) resource Admin {
        access(all) let ownedPools: @{UInt64: Pool}

        /// Internal pool creation. Called from commitToss after a toss completes.
        access(contract) fun createPool() {
            CoinFlip.totalPools = CoinFlip.totalPools + 1
            let newPool <- create Pool()
            self.ownedPools[newPool.id] <-! newPool
            emit NewPoolCreated(id: CoinFlip.totalPools)
        }

        /// Read-only pool reference for internal contract use.
        access(contract) view fun borrowPool(id: UInt64): &Pool? {
            return &self.ownedPools[id]
        }

        /// Pool reference with UpdateWinnings entitlement for share calculations.
        access(contract) view fun borrowEntitlementPool(id: UInt64): auth(CoinFlip.UpdateWinnings) &Pool? {
            return &self.ownedPools[id] as auth(CoinFlip.UpdateWinnings) &Pool?
        }

        /// Pool reference with Withdraw entitlement for fund movements.
        /// access(contract) — only called from tossCoin (Admin) and claimReward (contract).
        access(contract) view fun borrowWithdrawEntitlement(id: UInt64): auth(FungibleToken.Withdraw) &Pool? {
            return &self.ownedPools[id] as auth(FungibleToken.Withdraw) &Pool?
        }

        access(all) view fun getPoolIDs(): [UInt64] {
            return self.ownedPools.keys
        }

        access(all) view fun isCoinFlipped(id: UInt64): Bool {
            let poolRef = self.borrowPool(id: id) ?? panic("Pool not found")
            return poolRef.isCoinFlipped()
        }

        access(all) view fun poolEndTime(id: UInt64): UFix64 {
            let poolRef = self.borrowPool(id: id) ?? panic("Pool not found")
            return poolRef.endTime
        }

        /// Step 1 of the two-phase toss: record the current block height.
        /// The randomness at this block height is used in tossCoin() (step 2).
        ///
        /// Why two phases? revertibleRandom() is exploitable — a validator can
        /// abort the transaction and retry until a favourable outcome appears.
        /// RandomBeaconHistory randomness is sealed after the commit block and
        /// cannot be reverted, so the outcome cannot be gamed.
        access(all) fun commitToss(id: UInt64) {
            pre {
                !self.isCoinFlipped(id: id): "Coin already flipped for this pool"
                getCurrentBlock().timestamp >= self.poolEndTime(id: id): "Pool betting window not ended yet"
            }
            let poolRef = self.borrowPool(id: id) ?? panic("Pool not found")
            let height = getCurrentBlock().height
            poolRef.setCommittedHeight(newValue: height)
            poolRef.setStatus(newValue: PoolStatus.CALCULATING)
            emit TossCommitted(id: id, atBlockHeight: height)
        }

        /// Step 2 of the two-phase toss: fetch sealed randomness and resolve.
        ///
        /// Must be called at least one block after commitToss().
        access(all) fun tossCoin(id: UInt64) {
            let poolRef = self.borrowPool(id: id) ?? panic("Pool not found")
            pre {
                !self.isCoinFlipped(id: id): "Coin already flipped for this pool"
                poolRef.getCommittedHeight() != nil: "Must call commitToss first"
                getCurrentBlock().height > poolRef.getCommittedHeight()!: "Must wait at least 1 block after commit"
            }

            let committedHeight = poolRef.getCommittedHeight()!

            // Fetch non-revertible sealed randomness for the committed block.
            let source = RandomBeaconHistory.sourceOfRandomness(atBlockHeight: committedHeight)

            // Build a UInt64 from the first 8 bytes of the 32-byte beacon value.
            // XOR with pool id to add per-pool entropy.
            let b = source.value
            let raw: UInt64 = (UInt64(b[0]) << 56) | (UInt64(b[1]) << 48)
                | (UInt64(b[2]) << 40) | (UInt64(b[3]) << 32)
                | (UInt64(b[4]) << 24) | (UInt64(b[5]) << 16)
                | (UInt64(b[6]) << 8)  |  UInt64(b[7])
            let randomNumber: UInt64 = (raw ^ id) % 2 + 1  // 1 = HEAD, 2 = TAIL

            let tokenPoolRef = self.borrowWithdrawEntitlement(id: id) ?? panic("Pool not found")

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

        /// Calculate each head bettor's proportional share.
        /// Guard: if no head bettors, skip (no division by zero).
        access(contract) fun headUsersWinningShare(id: UInt64) {
            let poolRef = self.borrowEntitlementPool(id: id) ?? panic("Pool not found")
            let totalBalance = poolRef.headVault.balance
            if totalBalance == 0.0 {
                return  // no head bettors — nothing to distribute
            }
            let keys = poolRef.headInfo.keys
            var i = 0
            while i < poolRef.headInfo.length {
                let address = keys[i]
                let betAmount = poolRef.getHeadBetUserInfo(addr: address).bet_amount
                poolRef.set_h_winningShare(address: address, newValue: (betAmount / totalBalance) * 100.0)
                i = i + 1
            }
        }

        /// Calculate each tail bettor's proportional share.
        /// Guard: if no tail bettors, skip (no division by zero).
        access(contract) fun tailUsersWinningShare(id: UInt64) {
            let poolRef = self.borrowEntitlementPool(id: id) ?? panic("Pool not found")
            let totalBalance = poolRef.tailVault.balance
            if totalBalance == 0.0 {
                return  // no tail bettors — nothing to distribute
            }
            let keys = poolRef.tailInfo.keys
            var i = 0
            while i < poolRef.tailInfo.length {
                let address = keys[i]
                let betAmount = poolRef.getTailBetUserInfo(_addr: address).bet_amount
                poolRef.set_t_winningShare(address: address, newValue: (betAmount / totalBalance) * 100.0)
                i = i + 1
            }
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
            let share = poolRef.getHWinningShare(address: addr) ?? 0.0
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
            let share = poolRef.getTWinningShare(address: addr) ?? 0.0
            let reward = poolRef.getHeadBalance() * share / 100.0
            user.setClaimAmount(newAmount: betAmount + reward)
        }
        poolRef.setCoinFlipped(newValue: true)
        poolRef.setStatus(newValue: PoolStatus.CLOSE)
    }

    // ========================================================================
    // PUBLIC ACCESSORS — read-only; never exposes Admin or privileged refs
    // ========================================================================

    /// Internal: borrow Admin resource. Never exposed publicly.
    access(contract) view fun borrowAdmin(): &Admin {
        return self.account.storage.borrow<&CoinFlip.Admin>(from: /storage/CoinFlipGameManager)!
    }

    /// Internal: borrow Pool with Withdraw entitlement.
    /// Only used by claimReward (contract code) to process fund movements.
    access(contract) view fun borrowWithdrawEntitlement(id: UInt64): auth(FungibleToken.Withdraw) &CoinFlip.Pool {
        return self.borrowAdmin().borrowWithdrawEntitlement(id: id)
            ?? panic("Pool not found: ".concat(id.toString()))
    }

    /// Public read-only pool reference. Exposes only view functions and
    /// access(all) fields — no mutation possible via this reference.
    access(all) view fun borrowPool(id: UInt64): &Pool {
        return self.borrowAdmin().borrowPool(id: id) ?? panic("Pool not found: ".concat(id.toString()))
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
            self.borrowPool(id: poolId).isCoinFlipped(): "Coin not tossed yet"
            self.borrowPool(id: poolId).headInfo[userAddress] != nil ||
                self.borrowPool(id: poolId).tailInfo[userAddress] != nil: "You did not participate"
            self.borrowPool(id: poolId).headInfo[userAddress]?.choice == self.borrowPool(id: poolId).getTossResult() ||
                self.borrowPool(id: poolId).tailInfo[userAddress]?.choice == self.borrowPool(id: poolId).getTossResult(): "You lost — better luck next pool"
            // Exactly one of head/tail rewardClaimed must be false for this user's winning side.
            (self.borrowPool(id: poolId).headInfo[userAddress]?.rewardClaimed ?? false) == false &&
                (self.borrowPool(id: poolId).tailInfo[userAddress]?.rewardClaimed ?? false) == false: "Reward already claimed"
        }

        let result = self.borrowPool(id: poolId).getTossResult()

        if result == "HEAD" {
            let poolRef = self.borrowPool(id: poolId)
            let poolWithdrawRef = self.borrowWithdrawEntitlement(id: poolId)
            let user = poolRef.getHeadBetUserInfo(addr: userAddress)
            let userBetAmount = user.bet_amount
            let claimAmount = user.claim_amount
            let rewardAmount = claimAmount - userBetAmount
            user.setRewardClaimed(newValue: true)

            let betVault <- poolWithdrawRef.headVault.withdraw(amount: userBetAmount) as! @FlowToken.Vault
            let rewardVault <- poolWithdrawRef.poolVault.withdraw(amount: rewardAmount) as! @FlowToken.Vault

            if rewardVault.balance > 0.0 {
                let feeFromBet <- betVault.withdraw(amount: betVault.balance * 0.01) as! @FlowToken.Vault
                let feeFromReward <- rewardVault.withdraw(amount: rewardVault.balance * 0.01) as! @FlowToken.Vault
                let platformVault = CoinFlip.account.capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                    ?? panic("Could not borrow platform vault receiver")
                platformVault.deposit(from: <- feeFromBet)
                platformVault.deposit(from: <- feeFromReward)
            }

            let userReceiver = getAccount(userAddress).capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                ?? panic("User does not have a Flow Token receiver set up")
            userReceiver.deposit(from: <- betVault)
            userReceiver.deposit(from: <- rewardVault)
            emit RewardClaimed(id: poolId, address: userAddress, amount: claimAmount)

        } else {
            let poolRef = self.borrowPool(id: poolId)
            let poolWithdrawRef = self.borrowWithdrawEntitlement(id: poolId)
            let user = poolRef.getTailBetUserInfo(_addr: userAddress)
            let userBetAmount = user.bet_amount
            let claimAmount = user.claim_amount
            let rewardAmount = claimAmount - userBetAmount
            user.setRewardClaimed(newValue: true)

            let betVault <- poolWithdrawRef.tailVault.withdraw(amount: userBetAmount) as! @FlowToken.Vault
            let rewardVault <- poolWithdrawRef.poolVault.withdraw(amount: rewardAmount) as! @FlowToken.Vault

            if rewardVault.balance > 0.0 {
                let feeFromBet <- betVault.withdraw(amount: betVault.balance * 0.01) as! @FlowToken.Vault
                let feeFromReward <- rewardVault.withdraw(amount: rewardVault.balance * 0.01) as! @FlowToken.Vault
                let platformVault = CoinFlip.account.capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                    ?? panic("Could not borrow platform vault receiver")
                platformVault.deposit(from: <- feeFromBet)
                platformVault.deposit(from: <- feeFromReward)
            }

            let userReceiver = getAccount(userAddress).capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                ?? panic("User does not have a Flow Token receiver set up")
            userReceiver.deposit(from: <- betVault)
            userReceiver.deposit(from: <- rewardVault)
            emit RewardClaimed(id: poolId, address: userAddress, amount: claimAmount)
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

// cadence/contracts/systems/Staking.cdc
//
// Token staking system for Flow game studios.
//
// Design:
//   - Players stake GameTokens for a configurable lock period (in blocks).
//   - Tokens are escrowed in a single contract-level vault per-position.
//   - Yield is accumulated separately and paid from a funded yield pool.
//   - Yield formula: amount * yieldRatePerMille * blocksElapsed / (1_000_000)
//     where yieldRatePerMille=10 means 1% per 1000 blocks.
//   - Players cannot unstake before the lock period ends.
//   - claimYield is separate from unstake — players can claim yield anytime
//     and still keep their position locked.
//   - fundYieldPool is public (callable by anyone, including tests).
//
// Flat-state pattern (Cadence 1.0):
//   StakePosition struct fields cannot be mutated via dict subscript.
//   All mutable per-position state lives in flat maps.
//   getPosition() assembles a StakePosition view struct from flat state.
//
// Vault pattern (Cadence 1.0):
//   - stakeVault: single vault holding ALL staked principal.
//   - yieldVault: separate vault holding yield pool funded by Admin.
//   - Resource dict operations use `<-` move operator.
//   - Borrow references with auth(FungibleToken.Withdraw) for withdrawals.

import "FungibleToken"
import "GameToken"

access(all) contract Staking {

    // -----------------------------------------------------------------------
    // Entitlements
    // -----------------------------------------------------------------------

    /// Admin entitlement — held only by the AdminRef resource stored at deployer.
    access(all) entitlement Admin

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// Fires when a player stakes tokens.
    access(all) event Staked(positionId: UInt64, player: Address, amount: UFix64, lockBlocks: UInt64)

    /// Fires when a player unstakes principal after lock period.
    access(all) event Unstaked(positionId: UInt64, player: Address, amount: UFix64)

    /// Fires when a player claims yield.
    access(all) event YieldClaimed(positionId: UInt64, player: Address, yieldAmount: UFix64)

    // -----------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------

    /// Public read-only view of a stake position — assembled by getPosition().
    access(all) struct StakePosition {
        access(all) let id: UInt64
        access(all) let staker: Address
        access(all) let amount: UFix64
        access(all) let stakedAtBlock: UInt64
        access(all) let lockBlocks: UInt64
        access(all) let yieldRatePerMille: UInt64
        access(all) let claimed: Bool

        init(
            id: UInt64,
            staker: Address,
            amount: UFix64,
            stakedAtBlock: UInt64,
            lockBlocks: UInt64,
            yieldRatePerMille: UInt64,
            claimed: Bool
        ) {
            self.id                = id
            self.staker            = staker
            self.amount            = amount
            self.stakedAtBlock     = stakedAtBlock
            self.lockBlocks        = lockBlocks
            self.yieldRatePerMille = yieldRatePerMille
            self.claimed           = claimed
        }
    }

    // -----------------------------------------------------------------------
    // Immutable core data (written once at stake())
    // -----------------------------------------------------------------------

    /// Immutable per-position config — written once, never mutated.
    access(all) struct PositionCore {
        access(all) let id: UInt64
        access(all) let staker: Address
        access(all) let amount: UFix64
        access(all) let stakedAtBlock: UInt64
        access(all) let lockBlocks: UInt64
        access(all) let yieldRatePerMille: UInt64

        init(
            id: UInt64,
            staker: Address,
            amount: UFix64,
            stakedAtBlock: UInt64,
            lockBlocks: UInt64,
            yieldRatePerMille: UInt64
        ) {
            self.id                = id
            self.staker            = staker
            self.amount            = amount
            self.stakedAtBlock     = stakedAtBlock
            self.lockBlocks        = lockBlocks
            self.yieldRatePerMille = yieldRatePerMille
        }
    }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// Total positions ever created (also the next position ID).
    access(all) var totalPositions: UInt64

    /// Current yield rate in per-mille (e.g. 10 = 1% per 1000 blocks).
    /// Set by Admin; applies to new positions.
    access(all) var yieldRatePerMille: UInt64

    /// Immutable core data per position.
    access(self) var positionCore: {UInt64: PositionCore}

    /// Whether each position has been unstaked (principal claimed).
    access(self) var positionClaimed: {UInt64: Bool}

    /// Whether yield has been claimed for each position.
    access(self) var yieldClaimed: {UInt64: Bool}

    /// Single vault holding all staked principal.
    access(self) var stakeVault: @{FungibleToken.Vault}

    /// Separate vault funded by Admin for yield payouts.
    access(self) var yieldVault: @{FungibleToken.Vault}

    // -----------------------------------------------------------------------
    // Admin Resource
    // -----------------------------------------------------------------------

    /// AdminRef — stored at deployer account; never published to a public path.
    access(all) resource AdminRef {

        /// Update the yield rate (affects new positions only).
        access(Admin) fun setYieldRate(perMille: UInt64) {
            Staking.yieldRatePerMille = perMille
        }

        /// Fund the yield pool. Admin can call this to ensure payouts are possible.
        access(Admin) fun fundYieldPoolAdmin(payment: @{FungibleToken.Vault}) {
            Staking.yieldVault.deposit(from: <- payment)
        }
    }

    // -----------------------------------------------------------------------
    // Public functions
    // -----------------------------------------------------------------------

    /// Stake tokens. Escrows `payment`, records position, returns positionId.
    /// `lockBlocks` is the number of blocks before unstaking is allowed.
    access(all) fun stake(
        player: Address,
        payment: @{FungibleToken.Vault},
        lockBlocks: UInt64
    ): UInt64 {
        pre {
            payment.balance > UFix64(0): "Cannot stake zero tokens"
            lockBlocks > UInt64(0):      "Lock period must be at least 1 block"
        }

        let positionId   = Staking.totalPositions
        let amount       = payment.balance
        let currentBlock = getCurrentBlock().height
        let rate         = Staking.yieldRatePerMille

        // Escrow the tokens in the stake vault
        Staking.stakeVault.deposit(from: <- payment)

        // Record immutable core
        Staking.positionCore[positionId] = PositionCore(
            id:                positionId,
            staker:            player,
            amount:            amount,
            stakedAtBlock:     currentBlock,
            lockBlocks:        lockBlocks,
            yieldRatePerMille: rate
        )

        // Initialise mutable state
        Staking.positionClaimed[positionId] = false
        Staking.yieldClaimed[positionId]    = false
        Staking.totalPositions              = Staking.totalPositions + 1

        emit Staked(positionId: positionId, player: player, amount: amount, lockBlocks: lockBlocks)
        return positionId
    }

    /// Unstake principal. Requires lock period to have elapsed.
    /// Returns the principal vault to the caller for depositing.
    access(all) fun unstake(
        positionId: UInt64,
        player: Address
    ): @{FungibleToken.Vault} {
        let core = Staking.positionCore[positionId]
            ?? panic("Position not found: ".concat(positionId.toString()))

        assert(core.staker == player,  message: "Not position owner")
        assert(
            !(Staking.positionClaimed[positionId] ?? false),
            message: "Position already unstaked"
        )

        let currentBlock = getCurrentBlock().height
        assert(
            currentBlock >= core.stakedAtBlock + core.lockBlocks,
            message: "Lock period has not elapsed yet"
        )

        // Mark as claimed (copy-modify-write pattern on flat state)
        Staking.positionClaimed[positionId] = true

        // Withdraw principal from stake vault
        let stakeRef = (&Staking.stakeVault as auth(FungibleToken.Withdraw) &{FungibleToken.Vault})
        let principal <- stakeRef.withdraw(amount: core.amount)

        emit Unstaked(positionId: positionId, player: player, amount: core.amount)
        return <- principal
    }

    /// Claim yield for a position. Can be called multiple times (yield accumulates);
    /// but for simplicity, this implementation marks yield as claimed once.
    /// Yield = amount * yieldRatePerMille * blocksElapsed / 1_000_000
    access(all) fun claimYield(positionId: UInt64, player: Address) {
        let core = Staking.positionCore[positionId]
            ?? panic("Position not found: ".concat(positionId.toString()))

        assert(core.staker == player, message: "Not position owner")
        assert(
            !(Staking.yieldClaimed[positionId] ?? false),
            message: "Yield already claimed"
        )

        let currentBlock   = getCurrentBlock().height
        let blocksElapsed  = currentBlock - core.stakedAtBlock

        // Yield = amount * yieldRatePerMille * blocksElapsed / 1_000_000
        // Using integer arithmetic scaled to UFix64
        // yieldRatePerMille * blocksElapsed may overflow UInt64 for large values;
        // safe for reasonable game values (rate <= 1000, blocks <= 1_000_000).
        let yieldAmount = core.amount * UFix64(core.yieldRatePerMille * blocksElapsed) / UFix64(1_000_000)

        if yieldAmount > UFix64(0) {
            assert(
                Staking.yieldVault.balance >= yieldAmount,
                message: "Insufficient yield pool balance"
            )

            // Withdraw yield from yield vault
            let yieldRef = (&Staking.yieldVault as auth(FungibleToken.Withdraw) &{FungibleToken.Vault})
            let yieldPayout <- yieldRef.withdraw(amount: yieldAmount)

            // Send to player's token receiver
            let receiver = getAccount(player)
                .capabilities.get<&{FungibleToken.Receiver}>(GameToken.ReceiverPublicPath)
                .borrow() ?? panic("Player has no token receiver — run setup_token_vault.cdc first")
            receiver.deposit(from: <- yieldPayout)
        }

        // Mark yield as claimed
        Staking.yieldClaimed[positionId] = true

        emit YieldClaimed(positionId: positionId, player: player, yieldAmount: yieldAmount)
    }

    /// Fund the yield pool. Callable by anyone (for testing).
    access(all) fun fundYieldPool(payment: @{FungibleToken.Vault}) {
        Staking.yieldVault.deposit(from: <- payment)
    }

    // -----------------------------------------------------------------------
    // Read-only accessors
    // -----------------------------------------------------------------------

    /// Assemble and return a StakePosition view, or nil if not found.
    access(all) fun getPosition(_ id: UInt64): StakePosition? {
        if let core = Staking.positionCore[id] {
            return StakePosition(
                id:                core.id,
                staker:            core.staker,
                amount:            core.amount,
                stakedAtBlock:     core.stakedAtBlock,
                lockBlocks:        core.lockBlocks,
                yieldRatePerMille: core.yieldRatePerMille,
                claimed:           Staking.positionClaimed[id] ?? false
            )
        }
        return nil
    }

    /// Return current yield vault balance (useful for funding checks).
    access(all) view fun yieldPoolBalance(): UFix64 {
        return Staking.yieldVault.balance
    }

    /// Return current stake vault balance.
    access(all) view fun stakeVaultBalance(): UFix64 {
        return Staking.stakeVault.balance
    }

    // -----------------------------------------------------------------------
    // Init
    // -----------------------------------------------------------------------

    init() {
        self.totalPositions   = 0
        self.yieldRatePerMille = 10  // default: 1% per 1000 blocks

        self.positionCore    = {}
        self.positionClaimed = {}
        self.yieldClaimed    = {}

        // Create empty vaults for escrow and yield pool
        self.stakeVault <- GameToken.createEmptyVault(vaultType: Type<@GameToken.Vault>())
        self.yieldVault  <- GameToken.createEmptyVault(vaultType: Type<@GameToken.Vault>())

        self.account.storage.save(<- create AdminRef(), to: /storage/StakingAdmin)
    }
}

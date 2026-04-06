// cadence/contracts/systems/Tournament.cdc
//
// On-chain tournament system for Flow game studios.
//
// Design:
//   - Anyone can create a tournament with configurable name, max players,
//     entry fee, and duration (in epochs).
//   - Players join by paying the entry fee; tokens are escrowed per-tournament.
//   - Organizer starts the tournament by committing a VRF secret for bracket seeding.
//   - After the duration elapses, the organizer resolves with ranked players and
//     reveals the VRF secret to derive the bracket seed.
//   - Prizes are distributed 60% / 30% / 10% to the top three finishers.
//   - Winners claim their prize via claimPrize().
//
// Struct mutability note (Cadence 1.0):
//   In Cadence 1.0, struct fields cannot be mutated from outside the struct's
//   own scope (init, methods), even via copy-modify-write. The copy-modify-write
//   pattern does NOT work for any access-level field. Instead, mutable tournament
//   state is stored in separate flat dictionaries alongside the immutable core data.
//   getTournament() assembles a TournamentData view struct from these flat stores.
//
// VRF integration:
//   RandomVRF.commit/reveal use the contract deployer address as the "player"
//   and the tournament ID as the gameId. At least 1 block must pass between
//   start() and resolve() due to VRF beacon requirements.
//   `RandomBeaconHistory` must be available in the deployment environment.

import "FungibleToken"
import "GameToken"
import "Scheduler"
import "RandomVRF"

access(all) contract Tournament {

    // -----------------------------------------------------------------------
    // Entitlements
    // -----------------------------------------------------------------------

    /// Admin entitlement — reserved for future admin-only operations.
    access(all) entitlement Admin

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    /// Fires when a new tournament is created.
    access(all) event TournamentCreated(id: UInt64, name: String, maxPlayers: UInt32, entryFee: UFix64)
    /// Fires when a player successfully joins a tournament.
    access(all) event PlayerJoined(tournamentId: UInt64, player: Address)
    /// Fires when a tournament transitions to Active status.
    access(all) event TournamentStarted(tournamentId: UInt64, bracketSeed: UInt256)
    /// Fires when a tournament is resolved and prizes are allocated.
    access(all) event TournamentResolved(tournamentId: UInt64, winner: Address, prizePool: UFix64)
    /// Fires when a player claims their prize.
    access(all) event PrizeClaimed(tournamentId: UInt64, player: Address, amount: UFix64)

    // -----------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------

    /// Lifecycle status of a tournament.
    access(all) enum TournamentStatus: UInt8 {
        /// Accepting new registrations.
        access(all) case Registration
        /// Active — no new registrations; bracket locked.
        access(all) case Active
        /// Prizes distributed; tournament complete.
        access(all) case Resolved
        /// Tournament cancelled (future use).
        access(all) case Cancelled
    }

    /// Read-only view of a tournament — assembled by getTournament() from flat state.
    /// All fields are immutable; mutation happens via the flat dictionaries below.
    access(all) struct TournamentData {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let maxPlayers: UInt32
        access(all) let entryFee: UFix64
        access(all) let durationEpochs: UInt64
        access(all) let status: TournamentStatus
        access(all) let players: [Address]
        access(all) let prizePool: UFix64
        access(all) let bracketSeed: UInt256
        access(all) let prizes: {Address: UFix64}
        access(all) let startEpoch: UInt64

        init(
            id: UInt64,
            name: String,
            maxPlayers: UInt32,
            entryFee: UFix64,
            durationEpochs: UInt64,
            status: TournamentStatus,
            players: [Address],
            prizePool: UFix64,
            bracketSeed: UInt256,
            prizes: {Address: UFix64},
            startEpoch: UInt64
        ) {
            self.id           = id
            self.name         = name
            self.maxPlayers   = maxPlayers
            self.entryFee     = entryFee
            self.durationEpochs = durationEpochs
            self.status       = status
            self.players      = players
            self.prizePool    = prizePool
            self.bracketSeed  = bracketSeed
            self.prizes       = prizes
            self.startEpoch   = startEpoch
        }
    }

    // -----------------------------------------------------------------------
    // Immutable core data (written once at createTournament)
    // -----------------------------------------------------------------------

    /// Core config data — written once, never mutated.
    access(all) struct TournamentCore {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let maxPlayers: UInt32
        access(all) let entryFee: UFix64
        access(all) let durationEpochs: UInt64

        init(id: UInt64, name: String, maxPlayers: UInt32, entryFee: UFix64, durationEpochs: UInt64) {
            self.id             = id
            self.name           = name
            self.maxPlayers     = maxPlayers
            self.entryFee       = entryFee
            self.durationEpochs = durationEpochs
        }
    }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// Total number of tournaments ever created (also next tournament ID).
    access(all) var totalTournaments: UInt64

    /// Immutable core config per tournament.
    access(self) var tournamentCore: {UInt64: TournamentCore}

    /// Mutable status per tournament.
    access(self) var tournamentStatus: {UInt64: TournamentStatus}

    /// Mutable player lists per tournament.
    access(self) var tournamentPlayers: {UInt64: [Address]}

    /// Accumulated prize pool per tournament (sum of entry fees paid).
    access(self) var tournamentPrizePool: {UInt64: UFix64}

    /// Bracket seed per tournament (set after VRF reveal in resolve).
    access(self) var tournamentBracketSeed: {UInt64: UInt256}

    /// Prize allocations per tournament: playerAddress -> claimable amount.
    access(self) var tournamentPrizes: {UInt64: {Address: UFix64}}

    /// Start epoch per tournament (set in start()).
    access(self) var tournamentStartEpoch: {UInt64: UInt64}

    /// Per-tournament entry fee vaults — escrowed until resolve or cancel.
    access(self) var entryFeeVaults: @{UInt64: {FungibleToken.Vault}}

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// Asserts a tournament exists.
    access(self) view fun assertExists(_ id: UInt64) {
        assert(self.tournamentCore[id] != nil, message: "Tournament not found: ".concat(id.toString()))
    }

    // -----------------------------------------------------------------------
    // Public functions
    // -----------------------------------------------------------------------

    /// Create a new tournament. Anyone can call this.
    /// Returns the new tournament ID.
    access(all) fun createTournament(
        name: String,
        maxPlayers: UInt32,
        entryFee: UFix64,
        durationEpochs: UInt64
    ): UInt64 {
        pre {
            name.length > 0:              "Tournament name cannot be empty"
            maxPlayers >= UInt32(2):      "Tournament needs at least 2 players"
            durationEpochs > UInt64(0):   "Duration must be at least 1 epoch"
        }

        let id = Tournament.totalTournaments

        // Flat state initialisation
        Tournament.tournamentCore[id] = TournamentCore(
            id: id, name: name, maxPlayers: maxPlayers,
            entryFee: entryFee, durationEpochs: durationEpochs
        )
        Tournament.tournamentStatus[id]       = TournamentStatus.Registration
        Tournament.tournamentPlayers[id]      = []
        Tournament.tournamentPrizePool[id]    = 0.0
        Tournament.tournamentBracketSeed[id]  = 0
        Tournament.tournamentPrizes[id]       = {}
        Tournament.tournamentStartEpoch[id]   = 0

        // Create an empty vault for this tournament's prize pool escrow
        Tournament.entryFeeVaults[id] <-! GameToken.createEmptyVault(
            vaultType: Type<@GameToken.Vault>()
        )

        Tournament.totalTournaments = Tournament.totalTournaments + 1

        emit TournamentCreated(id: id, name: name, maxPlayers: maxPlayers, entryFee: entryFee)
        return id
    }

    /// Join a tournament by paying the entry fee.
    /// `entryPayment` is moved into the per-tournament escrow vault.
    access(all) fun join(
        tournamentId: UInt64,
        player: Address,
        entryPayment: @{FungibleToken.Vault}
    ) {
        pre {
            Tournament.tournamentCore[tournamentId] != nil:
                "Tournament not found"
            Tournament.tournamentStatus[tournamentId] == TournamentStatus.Registration:
                "Tournament is not in Registration status"
            UInt32(Tournament.tournamentPlayers[tournamentId]!.length) <
                Tournament.tournamentCore[tournamentId]!.maxPlayers:
                "Tournament is full"
            entryPayment.balance >= Tournament.tournamentCore[tournamentId]!.entryFee:
                "Insufficient entry fee"
        }

        // Guard: player cannot join the same tournament twice
        let players = Tournament.tournamentPlayers[tournamentId]!
        for existingPlayer in players {
            assert(existingPlayer != player, message: "Player already joined this tournament")
        }

        // Deposit entry fee into per-tournament vault via borrow reference
        let vaultRef = (&Tournament.entryFeeVaults[tournamentId]
            as &{FungibleToken.Vault}?)
            ?? panic("Prize vault not found for tournament")
        vaultRef.deposit(from: <- entryPayment)

        // Update flat state
        Tournament.tournamentPlayers[tournamentId]!.append(player)
        let fee = Tournament.tournamentCore[tournamentId]!.entryFee
        Tournament.tournamentPrizePool[tournamentId] =
            (Tournament.tournamentPrizePool[tournamentId] ?? 0.0) + fee

        emit PlayerJoined(tournamentId: tournamentId, player: player)
    }

    /// Start the tournament: commits a VRF secret for bracket seeding and
    /// transitions status to Active.
    access(all) fun start(tournamentId: UInt64, vrfSecret: UInt256) {
        pre {
            Tournament.tournamentCore[tournamentId] != nil:
                "Tournament not found"
            Tournament.tournamentStatus[tournamentId] == TournamentStatus.Registration:
                "Tournament must be in Registration status to start"
            Tournament.tournamentPlayers[tournamentId]!.length >= 2:
                "Need at least 2 players to start"
        }

        // Commit VRF — uses the contract deployer address as the "player"
        // and the tournament ID as the gameId
        RandomVRF.commit(
            secret: vrfSecret,
            gameId: tournamentId,
            player: Tournament.account.address
        )

        // Update flat state
        Tournament.tournamentStatus[tournamentId]     = TournamentStatus.Active
        Tournament.tournamentStartEpoch[tournamentId] = Scheduler.currentEpoch

        // Bracket seed is 0 until revealed in resolve()
        emit TournamentStarted(tournamentId: tournamentId, bracketSeed: UInt256(0))
    }

    /// Resolve the tournament: reveals VRF, distributes prize allocations (60/30/10%),
    /// and sets status to Resolved.
    /// `rankedPlayers` must be ordered from 1st place to last.
    access(all) fun resolve(
        tournamentId: UInt64,
        rankedPlayers: [Address],
        vrfSecret: UInt256
    ) {
        pre {
            Tournament.tournamentCore[tournamentId] != nil:
                "Tournament not found"
            Tournament.tournamentStatus[tournamentId] == TournamentStatus.Active:
                "Tournament must be Active to resolve"
            rankedPlayers.length > 0: "Must provide at least one ranked player"
        }

        let core        = Tournament.tournamentCore[tournamentId]!
        let startEpoch  = Tournament.tournamentStartEpoch[tournamentId] ?? UInt64(0)
        let totalPrize  = Tournament.tournamentPrizePool[tournamentId] ?? 0.0

        // Duration check: current epoch >= startEpoch + durationEpochs
        assert(
            Scheduler.currentEpoch >= startEpoch + core.durationEpochs,
            message: "Tournament duration has not elapsed yet"
        )

        // Reveal VRF to derive bracket seed
        let bracketSeed = RandomVRF.reveal(
            secret: vrfSecret,
            gameId: tournamentId,
            player: Tournament.account.address
        )

        // Calculate prize allocations
        // 3+ players: 60% / 30% / 10%
        // 2 players:  70% / 30%
        // 1 player:   100%
        var prizes: {Address: UFix64} = {}
        let winner = rankedPlayers[0]

        if rankedPlayers.length >= 3 && totalPrize > 0.0 {
            let third  = totalPrize * 0.1
            let second = totalPrize * 0.3
            let first  = totalPrize - second - third   // remainder avoids rounding loss

            prizes[winner]           = first
            prizes[rankedPlayers[1]] = second
            prizes[rankedPlayers[2]] = third

        } else if rankedPlayers.length == 2 && totalPrize > 0.0 {
            let second = totalPrize * 0.3
            let first  = totalPrize - second

            prizes[winner]           = first
            prizes[rankedPlayers[1]] = second

        } else {
            prizes[winner] = totalPrize
        }

        // Update flat state
        Tournament.tournamentStatus[tournamentId]      = TournamentStatus.Resolved
        Tournament.tournamentBracketSeed[tournamentId] = bracketSeed
        Tournament.tournamentPrizes[tournamentId]      = prizes

        emit TournamentResolved(tournamentId: tournamentId, winner: winner, prizePool: totalPrize)
    }

    /// Claim a prize. Transfers the player's allocated amount to their token vault.
    access(all) fun claimPrize(tournamentId: UInt64, player: Address) {
        assert(
            Tournament.tournamentStatus[tournamentId] == TournamentStatus.Resolved,
            message: "Tournament is not resolved"
        )

        let prizes = Tournament.tournamentPrizes[tournamentId]
            ?? panic("Prize map not found for tournament")
        let amount = prizes[player] ?? panic("No prize for this player")
        assert(amount > 0.0, message: "Prize already claimed or zero")

        // Withdraw from the prize vault (requires Withdraw entitlement)
        let prizeVaultRef = (&Tournament.entryFeeVaults[tournamentId]
            as auth(FungibleToken.Withdraw) &{FungibleToken.Vault}?)
            ?? panic("Prize vault not found")
        let payout <- prizeVaultRef.withdraw(amount: amount)

        // Zero out prize to prevent double-claim
        var updatedPrizes = Tournament.tournamentPrizes[tournamentId] ?? {}
        updatedPrizes[player] = 0.0
        Tournament.tournamentPrizes[tournamentId] = updatedPrizes

        // Send to player's token receiver
        let receiver = getAccount(player)
            .capabilities.get<&{FungibleToken.Receiver}>(GameToken.ReceiverPublicPath)
            .borrow() ?? panic("Player has no token receiver — run setup_token_vault.cdc")
        receiver.deposit(from: <- payout)

        emit PrizeClaimed(tournamentId: tournamentId, player: player, amount: amount)
    }

    // -----------------------------------------------------------------------
    // Read-only accessors
    // -----------------------------------------------------------------------

    /// Assembles and returns a TournamentData view, or nil if not found.
    access(all) fun getTournament(_ id: UInt64): TournamentData? {
        if self.tournamentCore[id] == nil { return nil }
        let core = self.tournamentCore[id]!
        return TournamentData(
            id:             core.id,
            name:           core.name,
            maxPlayers:     core.maxPlayers,
            entryFee:       core.entryFee,
            durationEpochs: core.durationEpochs,
            status:         self.tournamentStatus[id] ?? TournamentStatus.Registration,
            players:        self.tournamentPlayers[id] ?? [],
            prizePool:      self.tournamentPrizePool[id] ?? 0.0,
            bracketSeed:    self.tournamentBracketSeed[id] ?? 0,
            prizes:         self.tournamentPrizes[id] ?? {},
            startEpoch:     self.tournamentStartEpoch[id] ?? 0
        )
    }

    /// Returns all tournament IDs with the given status.
    access(all) fun getTournamentsByStatus(_ status: TournamentStatus): [UInt64] {
        let result: [UInt64] = []
        var id: UInt64 = 0
        while id < self.totalTournaments {
            if self.tournamentStatus[id] == status {
                result.append(id)
            }
            id = id + 1
        }
        return result
    }

    // -----------------------------------------------------------------------
    // Init
    // -----------------------------------------------------------------------

    init() {
        self.totalTournaments        = 0
        self.tournamentCore          = {}
        self.tournamentStatus        = {}
        self.tournamentPlayers       = {}
        self.tournamentPrizePool     = {}
        self.tournamentBracketSeed   = {}
        self.tournamentPrizes        = {}
        self.tournamentStartEpoch    = {}
        self.entryFeeVaults          <- {}
    }
}

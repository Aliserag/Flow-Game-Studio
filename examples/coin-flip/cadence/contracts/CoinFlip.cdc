/// CoinFlip — provably fair coin flip using Flow's RandomBeaconHistory VRF.
///
/// Pattern: commit/reveal
///   1. Player submits SHA3_256(secret ++ playerAddress) as a commitment hash.
///      The current block height is recorded as the commit block.
///   2. At least one block must pass so that block's randomness is sealed.
///   3. Player reveals the secret; the contract fetches
///      RandomBeaconHistory.sourceOfRandomness(atBlockHeight: commitBlock),
///      XORs it with the secret, and determines heads (true) or tails (false).
///
/// Cadence 1.0 — no `pub`/`priv`, no 0.x patterns.
import RandomBeaconHistory from "RandomBeaconHistory"

access(all) contract CoinFlip {

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// Fired when a player submits a commit hash.
    access(all) event FlipCommitted(
        player: Address,
        flipId: UInt64,
        commitBlockHeight: UInt64
    )

    /// Fired when a flip is revealed and the result is determined.
    access(all) event FlipRevealed(
        player: Address,
        flipId: UInt64,
        result: Bool,
        playerChoice: Bool,
        won: Bool
    )

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    /// Monotonically increasing ID assigned to each new commit.
    access(all) var nextFlipId: UInt64

    /// Lifetime statistics.
    access(all) var totalFlips: UInt64
    access(all) var totalWins: UInt64

    /// player address → flip ID → Commit
    access(all) var commits: {Address: {UInt64: Commit}}

    // -------------------------------------------------------------------------
    // Types
    // -------------------------------------------------------------------------

    /// Represents a single coin-flip lifecycle from commit to resolution.
    ///
    /// Fields are all set at construction time.  The contract stores the
    /// unresolved form first (isResolved=false, result=nil, won=nil), then
    /// replaces it with a resolved copy after reveal.
    access(all) struct Commit {
        /// SHA3_256(secret ++ playerAddress) submitted by the player.
        access(all) let commitHash: [UInt8]

        /// Block height at which the commit was recorded.
        access(all) let commitBlockHeight: UInt64

        /// Whether reveal() has been called for this flip.
        access(all) let isResolved: Bool

        /// Nil until revealed; true = heads, false = tails.
        access(all) let result: Bool?

        /// What the player chose (true = heads, false = tails).
        access(all) let playerChoice: Bool

        /// Nil until revealed; true if playerChoice == result.
        access(all) let won: Bool?

        init(
            commitHash: [UInt8],
            commitBlockHeight: UInt64,
            playerChoice: Bool,
            isResolved: Bool,
            result: Bool?,
            won: Bool?
        ) {
            self.commitHash = commitHash
            self.commitBlockHeight = commitBlockHeight
            self.playerChoice = playerChoice
            self.isResolved = isResolved
            self.result = result
            self.won = won
        }
    }

    // -------------------------------------------------------------------------
    // Public contract functions
    // -------------------------------------------------------------------------

    /// Record a commitment from `player`.
    ///
    /// - Parameter player: Address of the player (signer of commit_flip.cdc).
    /// - Parameter commitHash: SHA3_256(secret ++ playerAddress) as raw bytes.
    /// - Parameter playerChoice: true = heads, false = tails.
    /// - Returns: The flip ID assigned to this commit.
    access(all) fun commit(
        player: Address,
        commitHash: [UInt8],
        playerChoice: Bool
    ): UInt64 {
        let flipId = self.nextFlipId
        self.nextFlipId = self.nextFlipId + 1

        let newCommit = Commit(
            commitHash: commitHash,
            commitBlockHeight: getCurrentBlock().height,
            playerChoice: playerChoice,
            isResolved: false,
            result: nil,
            won: nil
        )

        // Build or update the player's commit map.
        // We must read, mutate, then write back because dictionary subscript
        // returns a copy in Cadence.
        if self.commits[player] == nil {
            self.commits[player] = {flipId: newCommit}
        } else {
            var playerMap = self.commits[player]!
            playerMap[flipId] = newCommit
            self.commits[player] = playerMap
        }

        self.totalFlips = self.totalFlips + 1

        emit FlipCommitted(
            player: player,
            flipId: flipId,
            commitBlockHeight: newCommit.commitBlockHeight
        )

        return flipId
    }

    /// Reveal the secret for a previously committed flip.
    ///
    /// Verification steps:
    ///   1. Commit must exist and not yet be resolved.
    ///   2. Current block height must be strictly greater than commitBlockHeight
    ///      so the beacon randomness for that block is sealed.
    ///   3. XOR the beacon value with `secret` and take modulo 2.
    ///      0 → heads (true), 1 → tails (false).
    ///
    /// - Parameter player: Address of the player.
    /// - Parameter flipId: ID returned from `commit()`.
    /// - Parameter secret: The secret UInt256 used to generate the commitHash.
    /// - Returns: true if the player won, false otherwise.
    access(all) fun reveal(
        player: Address,
        flipId: UInt64,
        secret: UInt256
    ): Bool {
        let playerMap = self.commits[player]
            ?? panic("No commits found for player")
        let existingCommit = playerMap[flipId]
            ?? panic("Flip ID not found for player")

        if existingCommit.isResolved {
            panic("Flip already resolved")
        }

        let currentHeight = getCurrentBlock().height
        if currentHeight <= existingCommit.commitBlockHeight {
            panic("Must wait at least one block after commit before revealing")
        }

        // Fetch the sealed randomness for the commit block.
        let randomSource = RandomBeaconHistory.sourceOfRandomness(
            atBlockHeight: existingCommit.commitBlockHeight
        )

        // Convert [UInt8] beacon value to UInt256 for arithmetic.
        // The real RandomBeaconHistory returns 32 bytes; we interpret them big-endian.
        var beaconUInt256: UInt256 = 0
        for byte in randomSource.value {
            beaconUInt256 = (beaconUInt256 << 8) | UInt256(byte)
        }

        // Derive result: XOR beacon value with player secret, modulo 2.
        // 0 → heads (true), 1 → tails (false).
        let combined: UInt256 = beaconUInt256 ^ secret
        let flipResult: Bool = (combined % 2) == 0

        let flipWon = flipResult == existingCommit.playerChoice

        // Replace the existing commit with a resolved copy.
        // Read map → mutate → write back (Cadence dictionary copy semantics).
        let resolvedCommit = Commit(
            commitHash: existingCommit.commitHash,
            commitBlockHeight: existingCommit.commitBlockHeight,
            playerChoice: existingCommit.playerChoice,
            isResolved: true,
            result: flipResult,
            won: flipWon
        )
        var updatedMap = self.commits[player]!
        updatedMap[flipId] = resolvedCommit
        self.commits[player] = updatedMap

        if flipWon {
            self.totalWins = self.totalWins + 1
        }

        emit FlipRevealed(
            player: player,
            flipId: flipId,
            result: flipResult,
            playerChoice: existingCommit.playerChoice,
            won: flipWon
        )

        return flipWon
    }

    // -------------------------------------------------------------------------
    // Read-only accessors (for scripts — return value copies, not references)
    // -------------------------------------------------------------------------

    /// Return a single Commit, or nil if not found.
    access(all) fun getFlip(player: Address, flipId: UInt64): Commit? {
        if let playerMap = self.commits[player] {
            return playerMap[flipId]
        }
        return nil
    }

    /// Return all Commits for a player (empty dict if none).
    access(all) fun getFlipsForPlayer(player: Address): {UInt64: Commit} {
        return self.commits[player] ?? {}
    }

    // -------------------------------------------------------------------------
    // init
    // -------------------------------------------------------------------------

    init() {
        self.nextFlipId = 0
        self.totalFlips = 0
        self.totalWins = 0
        self.commits = {}
    }
}

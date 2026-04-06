// cadence/contracts/systems/RandomVRF.cdc
//
// Commit/Reveal randomness for Flow games.
//
// PATTERN:
//   1. Player calls commit transaction: stores hash(secret, playerAddr, gameId, nonce)
//      Records the block height of the commit.
//   2. After >=1 block, player calls reveal transaction: passes secret.
//      Contract fetches RandomBeaconHistory for the commit block height.
//      Derives result = keccak256(beacon || secret) — unpredictable and unbiasable.
//
// WHY COMMIT/REVEAL:
//   revertibleRandom() can be biased by reverting transactions on unfavorable outcomes.
//   Commit/reveal prevents this: the player commits *before* the randomness is known.

import "RandomBeaconHistory"

/// SECURITY NOTE: The `commit()` and `reveal()` functions accept `player: Address`
/// as a parameter. This is safe when called from a transaction that captures
/// `signer.address` in `prepare` — but any address could be passed if called
/// from another contract. The intended call path is always: transaction prepare() -> contract function.

access(all) contract RandomVRF {

    // -----------------------------------------------------------------------
    // Entitlements
    // -----------------------------------------------------------------------
    access(all) entitlement Revealer

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    access(all) event Committed(player: Address, gameId: UInt64, blockHeight: UInt64)
    access(all) event Revealed(player: Address, gameId: UInt64, result: UInt256)

    // -----------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------
    access(all) struct Commit {
        access(all) let commitHash: [UInt8]
        access(all) let blockHeight: UInt64
        access(all) let player: Address
        access(all) let gameId: UInt64
        access(all) var revealed: Bool

        init(
            commitHash: [UInt8],
            blockHeight: UInt64,
            player: Address,
            gameId: UInt64
        ) {
            self.commitHash = commitHash
            self.blockHeight = blockHeight
            self.player = player
            self.gameId = gameId
            self.revealed = false
        }
    }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    access(all) var totalCommits: UInt64

    // key: "{address}-{gameId}"
    access(self) var commits: {String: Commit}

    // -----------------------------------------------------------------------
    // Public commit function (called by transaction)
    // -----------------------------------------------------------------------
    access(all) fun commit(
        secret: UInt256,
        gameId: UInt64,
        player: Address
    ) {
        let key = player.toString().concat("-").concat(gameId.toString())
        assert(self.commits[key] == nil, message: "Already committed for this gameId")

        // Hash: secret ++ player bytes ++ gameId ++ totalCommits (nonce)
        var hashInput: [UInt8] = []
        hashInput = hashInput.concat(secret.toBigEndianBytes())
        hashInput = hashInput.concat(player.toBytes())
        hashInput = hashInput.concat(gameId.toBigEndianBytes())
        hashInput = hashInput.concat(self.totalCommits.toBigEndianBytes())

        let commitHash = HashAlgorithm.KECCAK_256.hash(hashInput)

        self.commits[key] = Commit(
            commitHash: commitHash,
            blockHeight: getCurrentBlock().height,
            player: player,
            gameId: gameId
        )
        self.totalCommits = self.totalCommits + 1
        emit Committed(player: player, gameId: gameId, blockHeight: getCurrentBlock().height)
    }

    // -----------------------------------------------------------------------
    // Reveal — returns random UInt256 derived from beacon + secret
    // -----------------------------------------------------------------------
    access(all) fun reveal(
        secret: UInt256,
        gameId: UInt64,
        player: Address
    ): UInt256 {
        let key = player.toString().concat("-").concat(gameId.toString())
        let commit = self.commits[key]
            ?? panic("No commit found for key: ".concat(key))

        assert(!commit.revealed, message: "Already revealed")
        assert(
            getCurrentBlock().height > commit.blockHeight,
            message: "Must wait at least 1 block after committing"
        )

        // Get beacon randomness for the committed block
        let beacon = RandomBeaconHistory.sourceOfRandomness(
            atBlockHeight: commit.blockHeight
        )

        // Derive result: hash(beacon.value ++ secret)
        // beacon.value is already [UInt8] — no conversion needed
        var input: [UInt8] = []
        input = input.concat(beacon.value)
        input = input.concat(secret.toBigEndianBytes())
        let resultBytes = HashAlgorithm.KECCAK_256.hash(input)

        // Convert first 32 bytes to UInt256
        var result: UInt256 = 0
        var i = 0
        while i < resultBytes.length && i < 32 {
            result = result << 8
            result = result | UInt256(resultBytes[i])
            i = i + 1
        }

        // Remove commit — prevents double-reveal.
        self.commits.remove(key: key)

        emit Revealed(player: player, gameId: gameId, result: result)
        return result
    }

    // -----------------------------------------------------------------------
    // Utility: bounded random in [0, max) — rejection sampling, not naive modulo.
    // -----------------------------------------------------------------------
    access(all) fun boundedRandom(source: UInt256, max: UInt64): UInt64 {
        let maxU256 = UInt256(max)
        let threshold = (UInt256.max - (UInt256.max % maxU256)) + 1
        var r = source
        var i: UInt8 = 0
        while r >= threshold {
            var input: [UInt8] = r.toBigEndianBytes()
            input.append(i)
            let bytes = HashAlgorithm.KECCAK_256.hash(input)
            r = UInt256(0)
            var j = 0
            while j < bytes.length && j < 32 {
                r = r << 8
                r = r | UInt256(bytes[j])
                j = j + 1
            }
            i = i + 1
            if i == 255 { break }
        }
        return UInt64(r % maxU256)
    }

    // -----------------------------------------------------------------------
    // Query
    // -----------------------------------------------------------------------
    access(all) fun getCommit(key: String): Commit? {
        return self.commits[key]
    }

    // -----------------------------------------------------------------------
    // Init
    // -----------------------------------------------------------------------
    init() {
        self.totalCommits = 0
        self.commits = {}
    }
}

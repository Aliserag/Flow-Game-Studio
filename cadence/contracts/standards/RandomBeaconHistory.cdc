/// RandomBeaconHistory — vendored stub for local emulator / testing.
///
/// On testnet:  0x8c5303eaa26202d6
/// On mainnet:  0xd7431fd358660d73
///
/// This minimal implementation is deterministic for emulator and `flow test`.
/// The production protocol contract provides true protocol-level randomness;
/// this stub derives a deterministic value from the block height so tests
/// can verify the commit/reveal logic without a live network.
access(all) contract RandomBeaconHistory {

    /// Holds the random source for a given block height.
    access(all) struct RandomSource {
        /// Block height this source is bound to.
        access(all) let atBlockHeight: UInt64
        /// 256-bit random value (deterministic for emulator; protocol-provided on-chain).
        access(all) let value: UInt256

        init(atBlockHeight: UInt64, value: UInt256) {
            self.atBlockHeight = atBlockHeight
            self.value = value
        }
    }

    /// Returns the random source sealed at `atBlockHeight`.
    ///
    /// Emulator derivation: multiply by a large prime and XOR with a second constant
    /// so that adjacent heights produce very different values.  This is NOT
    /// cryptographically secure — it only exists to let tests exercise the
    /// contract logic.  The real protocol contract is provided by the network.
    access(all) fun sourceOfRandomness(atBlockHeight: UInt64): RandomSource {
        let h: UInt256 = UInt256(atBlockHeight)
        // Simple deterministic hash: multiply in a large prime and XOR with an offset.
        // UInt256 does not support wrapping arithmetic (&*), so we keep the prime small
        // enough that multiplication stays within UInt256 range for realistic block heights.
        // Max block height ~1e12; prime ~1e10 → product ~1e22, well within UInt256.
        let prime: UInt256  = 10000000007
        let offset: UInt256 = 6364136223846793005
        let seed: UInt256 = (h * prime) ^ offset
        return RandomSource(atBlockHeight: atBlockHeight, value: seed)
    }
}

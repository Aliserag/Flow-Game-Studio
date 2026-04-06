/// RandomBeaconHistory — vendored stub for local emulator / testing.
///
/// On testnet:  0x8c5303eaa26202d6
/// On mainnet:  0xd7431fd358660d73
///
/// IMPORTANT: `value` is `[UInt8]` (32 bytes) — matching the real protocol
/// contract. Contracts must convert bytes to UInt256 before arithmetic.
access(all) contract RandomBeaconHistory {

    access(all) struct RandomSource {
        access(all) let atBlockHeight: UInt64
        /// 32-byte random value. Matches the real RandomBeaconHistory interface.
        access(all) let value: [UInt8]

        init(atBlockHeight: UInt64, value: [UInt8]) {
            self.atBlockHeight = atBlockHeight
            self.value = value
        }
    }

    /// Deterministic stub for emulator/testing only.
    /// Spreads the block height across 32 bytes using XOR + shift.
    /// NOT cryptographically secure.
    access(all) fun sourceOfRandomness(atBlockHeight: UInt64): RandomSource {
        // XOR the block height with 4 distinct 64-bit constants.
        // Each constant produces 8 bytes → 32 bytes total.
        let h = atBlockHeight
        let c0: UInt64 = 0x6c62272e07bb0142
        let c1: UInt64 = 0xb492b66fbe98f273
        let c2: UInt64 = 0x9ae16a3b2f90404f
        let c3: UInt64 = 0xdeadbeefcafebabe

        let m0 = h ^ c0
        let m1 = h ^ c1
        let m2 = h ^ c2
        let m3 = h ^ c3

        let bytes: [UInt8] = [
            UInt8((m0 >> 56) & 0xFF), UInt8((m0 >> 48) & 0xFF),
            UInt8((m0 >> 40) & 0xFF), UInt8((m0 >> 32) & 0xFF),
            UInt8((m0 >> 24) & 0xFF), UInt8((m0 >> 16) & 0xFF),
            UInt8((m0 >> 8)  & 0xFF), UInt8( m0        & 0xFF),
            UInt8((m1 >> 56) & 0xFF), UInt8((m1 >> 48) & 0xFF),
            UInt8((m1 >> 40) & 0xFF), UInt8((m1 >> 32) & 0xFF),
            UInt8((m1 >> 24) & 0xFF), UInt8((m1 >> 16) & 0xFF),
            UInt8((m1 >> 8)  & 0xFF), UInt8( m1        & 0xFF),
            UInt8((m2 >> 56) & 0xFF), UInt8((m2 >> 48) & 0xFF),
            UInt8((m2 >> 40) & 0xFF), UInt8((m2 >> 32) & 0xFF),
            UInt8((m2 >> 24) & 0xFF), UInt8((m2 >> 16) & 0xFF),
            UInt8((m2 >> 8)  & 0xFF), UInt8( m2        & 0xFF),
            UInt8((m3 >> 56) & 0xFF), UInt8((m3 >> 48) & 0xFF),
            UInt8((m3 >> 40) & 0xFF), UInt8((m3 >> 32) & 0xFF),
            UInt8((m3 >> 24) & 0xFF), UInt8((m3 >> 16) & 0xFF),
            UInt8((m3 >> 8)  & 0xFF), UInt8( m3        & 0xFF)
        ]

        return RandomSource(atBlockHeight: atBlockHeight, value: bytes)
    }
}

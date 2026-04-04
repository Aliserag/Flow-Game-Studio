/// PrizePoolOrchestrator.cdc — Cadence controller for the Prize Pool wagering game.
///
/// This contract demonstrates Flow's unique superpower:
///   Cadence controlling EVM in the same transaction.
///
/// The flow of a round close:
///   1. Admin calls `closeRound` transaction, passing the EVM depositor list
///      (fetched via `getDepositors` off-chain) and a commit block height.
///   2. RandomBeaconHistory provides VRF — provably fair winner selection.
///   3. The COA (Cadence Owned Account) calls `PrizePool.closeRound(winner)`
///      on the EVM contract — transferring the entire prize pool.
///   4. WinnerTrophy NFT is minted to the winner's Cadence account.
///
/// COA ownership:
///   The deployer runs `setup_coa.cdc` once to create a COA in /storage/evm.
///   The EVM PrizePool contract must be owned by the COA's EVM address.
///   Cadence can then call `closeRound` and `openNewRound` on the EVM side.

import "EVM"
import "WinnerTrophy"
import "RandomBeaconHistory"

access(all) contract PrizePoolOrchestrator {

    /// Entitlement held by the Admin resource — gates privileged operations.
    access(all) entitlement OrchestratorAdmin

    /// The EVM PrizePool contract address (set by Admin after EVM deploy).
    /// Stored as optional — nil until Admin calls setPrizePoolAddress.
    access(all) var prizePoolEVMAddress: EVM.EVMAddress?

    /// Storage path for the COA. Must match setup_coa.cdc.
    access(all) let COAStoragePath: StoragePath

    /// Storage path for the Admin resource.
    access(all) let AdminStoragePath: StoragePath

    /// Running cadence round counter (separate from EVM roundId for indexing).
    access(all) var cadenceRoundCount: UInt64

    /// Emitted when a round closes successfully.
    access(all) event RoundClosed(
        cadenceRoundId: UInt64,
        evmRoundId: UInt256,
        winner: Address,
        evmWinner: String,
        prizeAmountStr: String,
        trophyId: UInt64
    )

    /// Emitted when the EVM PrizePool address is registered.
    access(all) event PrizePoolAddressSet(evmAddress: String)

    access(all) event ContractInitialized()

    // ─────────────────────────────────────────────────────────────────────────
    // Admin Resource
    // ─────────────────────────────────────────────────────────────────────────

    /// Admin resource — stored at deployer, never published publicly.
    access(all) resource Admin {

        /// Register the EVM PrizePool address after deploy.
        access(OrchestratorAdmin) fun setPrizePoolAddress(_ addr: EVM.EVMAddress) {
            PrizePoolOrchestrator.prizePoolEVMAddress = addr
            // Convert address bytes to hex string for the event
            let bytes = addr.bytes
            var hexStr = "0x"
            for b in bytes {
                let hi = b >> 4
                let lo = b & 0x0F
                let hexChars: [Character] = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
                hexStr = hexStr.concat(hexChars[hi].toString()).concat(hexChars[lo].toString())
            }
            emit PrizePoolAddressSet(evmAddress: hexStr)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Round Close — the heart of the cross-VM demo
    // ─────────────────────────────────────────────────────────────────────────

    /// Close the current Prize Pool round.
    ///
    /// This single Cadence transaction:
    ///   1. Uses RandomBeaconHistory VRF to select a winner from the depositor list
    ///   2. Calls EVM `PrizePool.closeRound(winner)` via the COA — releases funds
    ///   3. Mints a WinnerTrophy NFT to the winner's Cadence account
    ///
    /// Parameters:
    ///   - signer: the COA holder (deployer account)
    ///   - depositors: EVM addresses as 0x-prefixed hex strings (fetched off-chain)
    ///   - evmRoundId: the current EVM round ID (from PrizePool.roundId())
    ///   - commitBlockHeight: the sealed block height for RandomBeaconHistory VRF
    ///   - secret: additional entropy XORed with VRF value
    ///   - winnerFlowAddress: Cadence address to receive the trophy
    ///   - prizeAmountStr: prize total as string (for trophy metadata)
    ///
    access(all) fun closeRound(
        signer: auth(BorrowValue) &Account,
        depositors: [String],
        evmRoundId: UInt256,
        commitBlockHeight: UInt64,
        secret: UInt256,
        winnerFlowAddress: Address,
        prizeAmountStr: String
    ) {
        // ── Step 0: Validate inputs ───────────────────────────────────────────
        assert(depositors.length > 0, message: "PrizePoolOrchestrator: No depositors")

        let prizePoolAddr = PrizePoolOrchestrator.prizePoolEVMAddress
            ?? panic("PrizePoolOrchestrator: EVM address not set — call Admin.setPrizePoolAddress first")

        // ── Step 1: VRF — pick winner index ──────────────────────────────────
        //
        // RandomBeaconHistory.sourceOfRandomness() returns a cryptographically
        // committed random value from the Flow protocol for the given block.
        // We XOR with `secret` for additional admin entropy, then mod by the
        // depositor count.
        let randomSource = RandomBeaconHistory.sourceOfRandomness(atBlockHeight: commitBlockHeight)
        // Convert [UInt8] beacon value to UInt256 for arithmetic (big-endian).
        var beaconUInt256: UInt256 = 0
        for byte in randomSource.value {
            beaconUInt256 = (beaconUInt256 << 8) | UInt256(byte)
        }
        let randomValue = beaconUInt256 ^ secret
        let winnerIndex = UInt64(randomValue % UInt256(depositors.length))
        let winnerEVMAddrStr = depositors[winnerIndex]

        // ── Step 2: Encode EVM call — closeRound(address) ────────────────────
        //
        // ABI encoding for closeRound(address winner):
        //   - Function selector: keccak256("closeRound(address)") = 0x953ee60d
        //   - address parameter: right-aligned in 32-byte slot (12 zero bytes + 20 addr bytes)
        //
        // Strip "0x" prefix if present to get raw hex bytes
        let addrHex = winnerEVMAddrStr.length >= 2 && winnerEVMAddrStr.slice(from: 0, upTo: 2) == "0x"
            ? winnerEVMAddrStr.slice(from: 2, upTo: winnerEVMAddrStr.length)
            : winnerEVMAddrStr

        // Decode hex string to bytes (20 bytes for an EVM address)
        let winnerAddrBytes = addrHex.decodeHex()
        assert(winnerAddrBytes.length == 20,
            message: "PrizePoolOrchestrator: Invalid EVM address length — expected 20 bytes, got "
                .concat(winnerAddrBytes.length.toString()))

        // Build calldata: [selector (4 bytes)] + [12 zero padding bytes] + [20 address bytes]
        var callData: [UInt8] = [0x95, 0x3e, 0xe6, 0x0d]   // selector: closeRound(address)
        var i = 0
        while i < 12 {
            callData.append(0)                              // 12 bytes of left-padding
            i = i + 1
        }
        callData.appendAll(winnerAddrBytes)                 // 20 bytes of EVM address

        // ── Step 3: Call EVM via COA ──────────────────────────────────────────
        //
        // The COA (Cadence Owned Account) is a Flow-native EVM account controlled
        // by this Cadence account. It must be the `owner()` of the PrizePool
        // Solidity contract for this call to succeed.
        //
        // This is the unique Flow superpower: a Cadence transaction directly
        // calling a Solidity function in the same atomic transaction.
        let coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(
            from: PrizePoolOrchestrator.COAStoragePath
        ) ?? panic("PrizePoolOrchestrator: No COA at COAStoragePath — run setup_coa.cdc first")

        let result = coa.call(
            to: prizePoolAddr,
            data: callData,
            gasLimit: 100_000,
            value: EVM.Balance(attoflow: 0)
        )

        assert(
            result.status == EVM.Status.successful,
            message: "PrizePoolOrchestrator: EVM closeRound call failed"
        )

        // ── Step 4: Mint WinnerTrophy NFT ─────────────────────────────────────
        //
        // The trophy is minted to the winner's Cadence account.
        // The winner must have set up a WinnerTrophy collection first
        // (via setup_trophy_collection.cdc).
        let trophyMinter = PrizePoolOrchestrator.account.storage
            .borrow<auth(WinnerTrophy.Minter) &WinnerTrophy.MinterResource>(
                from: WinnerTrophy.MinterStoragePath
            ) ?? panic("PrizePoolOrchestrator: WinnerTrophy minter not found")

        let trophy <- trophyMinter.mint(
            roundId: PrizePoolOrchestrator.cadenceRoundCount,
            prizeAmount: prizeAmountStr,
            evmWinnerAddress: winnerEVMAddrStr
        )

        let trophyId = trophy.id

        // Deposit to winner's collection
        let winnerAccount = getAccount(winnerFlowAddress)
        let trophyReceiver = winnerAccount.capabilities
            .get<&WinnerTrophy.Collection>(WinnerTrophy.CollectionPublicPath)
            .borrow()
            ?? panic("PrizePoolOrchestrator: Winner has no WinnerTrophy collection — run setup_trophy_collection.cdc first")

        trophyReceiver.deposit(token: <- trophy)

        // Emit the trophy Minted event now that we know the winner address
        WinnerTrophy.emitMinted(
            id: trophyId,
            roundId: PrizePoolOrchestrator.cadenceRoundCount,
            winner: winnerFlowAddress,
            prizeAmount: prizeAmountStr
        )

        // ── Step 5: Bookkeeping ───────────────────────────────────────────────
        emit RoundClosed(
            cadenceRoundId: PrizePoolOrchestrator.cadenceRoundCount,
            evmRoundId: evmRoundId,
            winner: winnerFlowAddress,
            evmWinner: winnerEVMAddrStr,
            prizeAmountStr: prizeAmountStr,
            trophyId: trophyId
        )

        PrizePoolOrchestrator.cadenceRoundCount = PrizePoolOrchestrator.cadenceRoundCount + 1
    }

    // ─────────────────────────────────────────────────────────────────────────
    // init
    // ─────────────────────────────────────────────────────────────────────────

    init() {
        self.prizePoolEVMAddress = nil
        self.cadenceRoundCount = 0
        self.COAStoragePath = /storage/evm
        self.AdminStoragePath = /storage/prizePoolOrchestratorAdmin

        let admin <- create Admin()
        self.account.storage.save(<- admin, to: self.AdminStoragePath)

        emit ContractInitialized()
    }
}

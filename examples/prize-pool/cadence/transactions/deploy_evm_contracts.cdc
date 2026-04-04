/// deploy_evm_contracts.cdc — Deploy MockToken and PrizePool to Flow EVM via COA.
///
/// Flow-native EVM deployment: the Cadence Owned Account (COA) deploys both
/// contracts in a single Cadence transaction. The COA becomes msg.sender (and
/// Ownable.owner()) for both contracts — no transferOwnership() step needed.
///
/// Parameters:
///   - mockTokenBytecodeHex: MockToken creation bytecode + ABI-encoded constructor args.
///     Run `npm run compile` then the deploy-evm-cadence.mjs script encodes this.
///   - prizePoolBytecodeHex: PrizePool creation bytecode WITHOUT constructor args.
///     The constructor arg (MockToken address) is ABI-encoded inline below.
///
/// After running, deployed addresses appear in EVM.TransactionExecuted events
/// as the `contractAddress` field.
///
/// Run via deploy-evm-cadence.mjs (parses events and calls set_prize_pool_address.cdc).

import "EVM"

transaction(mockTokenBytecodeHex: String, prizePoolBytecodeHex: String) {
    prepare(signer: auth(BorrowValue) &Account) {
        let coa = signer.storage.borrow<auth(EVM.Deploy) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("No COA at /storage/evm — run setup_coa.cdc first")

        // ── Deploy MockToken ─────────────────────────────────────────────────
        // mockTokenBytecodeHex already contains ABI-encoded constructor args
        // (name, symbol, initialSupply) appended by deploy-evm-cadence.mjs.
        let mockTokenResult = coa.deploy(
            code: mockTokenBytecodeHex.decodeHex(),
            gasLimit: 3_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(
            mockTokenResult.status == EVM.Status.successful,
            message: "MockToken deploy failed: ".concat(mockTokenResult.errorMessage)
        )
        let mockTokenAddr = mockTokenResult.deployedContract!

        // ── ABI-encode PrizePool constructor arg: address _token ─────────────
        // ABI encoding for a single `address` value: 12 zero-padding bytes + 20 address bytes
        // mockTokenAddr.bytes is [UInt8; 20] (fixed-size); iterate to append each byte.
        var prizePoolCode = prizePoolBytecodeHex.decodeHex()
        var i: Int = 0
        while i < 12 {
            prizePoolCode.append(UInt8(0))
            i = i + 1
        }
        for b in mockTokenAddr.bytes {
            prizePoolCode.append(b)
        }

        // ── Deploy PrizePool ─────────────────────────────────────────────────
        let prizePoolResult = coa.deploy(
            code: prizePoolCode,
            gasLimit: 3_000_000,
            value: EVM.Balance(attoflow: 0)
        )
        assert(
            prizePoolResult.status == EVM.Status.successful,
            message: "PrizePool deploy failed: ".concat(prizePoolResult.errorMessage)
        )
        let prizePoolAddr = prizePoolResult.deployedContract!

        // ── Log addresses ────────────────────────────────────────────────────
        let hexChars: [Character] = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
        var mockHex = "0x"
        for b in mockTokenAddr.bytes {
            mockHex = mockHex.concat(hexChars[b >> 4].toString()).concat(hexChars[b & 0x0F].toString())
        }
        var poolHex = "0x"
        for b in prizePoolAddr.bytes {
            poolHex = poolHex.concat(hexChars[b >> 4].toString()).concat(hexChars[b & 0x0F].toString())
        }
        log("MockToken: ".concat(mockHex))
        log("PrizePool: ".concat(poolHex))
        log("COA is owner of both contracts — no transferOwnership needed")
    }
}

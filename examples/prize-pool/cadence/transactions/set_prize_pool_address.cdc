/// set_prize_pool_address.cdc — Register the deployed PrizePool EVM address in PrizePoolOrchestrator.
///
/// Must be run after deploy_evm_contracts.cdc.
/// Only the deployer (who holds the Admin resource) can call this.
///
/// Parameters:
///   - prizePoolHex: 0x-prefixed hex address of the deployed PrizePool Solidity contract.

import "PrizePoolOrchestrator"
import "EVM"

transaction(prizePoolHex: String) {
    prepare(signer: auth(BorrowValue) &Account) {
        let admin = signer.storage.borrow<auth(PrizePoolOrchestrator.OrchestratorAdmin) &PrizePoolOrchestrator.Admin>(
            from: /storage/prizePoolOrchestratorAdmin
        ) ?? panic("No Admin resource — are you the deployer?")

        // Strip 0x prefix if present
        let cleanHex = prizePoolHex.length >= 2 && prizePoolHex.slice(from: 0, upTo: 2) == "0x"
            ? prizePoolHex.slice(from: 2, upTo: prizePoolHex.length)
            : prizePoolHex

        let addrBytes = cleanHex.decodeHex()
        assert(addrBytes.length == 20, message: "Expected 20-byte address, got ".concat(addrBytes.length.toString()))

        let addr = EVM.EVMAddress(bytes: addrBytes.toConstantSized<20>()!)

        admin.setPrizePoolAddress(addr)
    }
}

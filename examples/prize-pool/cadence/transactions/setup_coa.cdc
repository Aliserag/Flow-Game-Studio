/// setup_coa.cdc — Create a Cadence Owned Account (COA) in Flow EVM for the signer.
///
/// The COA is an EVM-compatible account controlled by the Cadence account.
/// Its EVM address becomes the `owner()` of the deployed PrizePool Solidity contract.
///
/// Run once per deployer account. Idempotent — skips if COA already exists.
///
/// After running:
///   1. Call `get_coa_address.cdc` to retrieve the COA's EVM address.
///   2. Call `PrizePool.transferOwnership(<COA_EVM_ADDRESS>)` on the EVM side.
///   3. Call `Admin.setPrizePoolAddress` on PrizePoolOrchestrator.

import "EVM"

transaction {
    prepare(signer: auth(SaveValue, BorrowValue) &Account) {
        // Check if a COA already exists at /storage/evm
        if signer.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm) != nil {
            log("COA already exists — skipping creation")
            return
        }

        // Create a new COA and save it to /storage/evm
        let coa <- EVM.createCadenceOwnedAccount()
        let evmAddress = coa.address().toString()
        log("COA created. EVM address: ".concat(evmAddress))

        signer.storage.save(<- coa, to: /storage/evm)
        log("COA saved to /storage/evm")
        log("Next: call PrizePool.transferOwnership(\"".concat(evmAddress).concat("\") on EVM"))
    }
}

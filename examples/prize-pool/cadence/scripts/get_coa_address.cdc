/// get_coa_address.cdc — Returns the EVM address of the COA stored in a Flow account.
///
/// Returns nil if no COA exists (run setup_coa.cdc first).
/// Use the returned address to call `PrizePool.transferOwnership(coaAddress)` on EVM.

import "EVM"

access(all) fun main(flowAddress: Address): String? {
    return getAccount(flowAddress)
        .storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)
        ?.address()
        .toString()
}

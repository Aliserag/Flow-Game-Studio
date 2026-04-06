/// get_coa_address.cdc — Returns the EVM address of the COA stored in a Flow account.
///
/// Returns nil if no COA exists (run setup_coa.cdc first).
/// Use the returned address to call `PrizePool.transferOwnership(coaAddress)` on EVM.
///
/// Uses getAuthAccount (Cadence 1.0 script-inspection pattern) to read from storage.
/// EVMAddress has no toString() — bytes are converted to hex manually.

import "EVM"

access(all) fun main(flowAddress: Address): String? {
    let account = getAuthAccount<auth(Storage) &Account>(flowAddress)
    let coa = account.storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)
    if coa == nil { return nil }
    let addr = coa!.address()
    // EVM.EVMAddress.bytes is [UInt8; 20] — convert to 0x-prefixed hex string
    let hexChars: [Character] = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
    var hexStr = "0x"
    for b in addr.bytes {
        hexStr = hexStr
            .concat(hexChars[b >> 4].toString())
            .concat(hexChars[b & 0x0F].toString())
    }
    return hexStr
}

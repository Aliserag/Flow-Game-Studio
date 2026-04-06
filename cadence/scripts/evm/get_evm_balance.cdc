import EVM from 0x0000000000000001

access(all) fun main(flowAddress: Address): String {
    let coa = getAccount(flowAddress).storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)
        ?? panic("No EVM account for this Flow address")
    return coa.balance().inFLOW().toString()
}

// EVMBridge.cdc
// Wrapper around Flow's built-in EVM contract for game use cases.
// Flow EVM runs at the same address space as Cadence — cross-VM calls are native.
import EVM from 0x0000000000000001  // Built-in Flow EVM contract

access(all) contract EVMBridge {

    // Create a new EVM account controlled by this Cadence account
    access(all) fun createEVMAccount(signer: auth(SaveValue) &Account): EVM.EVMAddress {
        let coa <- EVM.createCadenceOwnedAccount()
        let addr = coa.address()
        signer.storage.save(<-coa, to: /storage/evm)
        return addr
    }

    // Get the EVM address of the Cadence-Owned Account (COA) for a Flow address
    access(all) fun getEVMAddress(flowAddress: Address): EVM.EVMAddress? {
        return getAccount(flowAddress).storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)?.address()
    }

    // Execute an EVM call from a COA
    access(all) fun callContract(
        signer: auth(BorrowValue) &Account,
        to: EVM.EVMAddress,
        data: [UInt8],
        gasLimit: UInt64,
        value: EVM.Balance
    ): EVM.Result {
        let coa = signer.storage.borrow<auth(EVM.Call) &EVM.CadenceOwnedAccount>(from: /storage/evm)
            ?? panic("No COA in storage — call createEVMAccount first")
        return coa.call(to: to, data: data, gasLimit: gasLimit, value: value)
    }
}

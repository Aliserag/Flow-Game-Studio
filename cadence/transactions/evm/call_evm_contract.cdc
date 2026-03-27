import "EVMBridge"
import EVM from 0x0000000000000001

// call_evm_contract.cdc
// Generic transaction to call any EVM contract from a Cadence-Owned Account (COA).
// ABI-encode `data` off-chain using ethers.js/Cast before sending.
transaction(contractAddrBytes: [UInt8; 20], data: [UInt8], gasLimit: UInt64, valueFLOW: UFix64) {

    prepare(signer: auth(BorrowValue) &Account) {
        let to = EVM.EVMAddress(bytes: contractAddrBytes)
        let value = EVM.Balance(attoflow: 0)
        // Note: valueFLOW conversion to attoflow omitted for brevity; set value = 0 for read-only calls

        let result = EVMBridge.callContract(
            signer: signer,
            to: to,
            data: data,
            gasLimit: gasLimit,
            value: value
        )

        assert(result.status == EVM.Status.successful,
            message: "EVM call failed with error code: ".concat(result.errorCode.toString()))

        log("EVM call succeeded. Gas used: ".concat(result.gasUsed.toString()))
    }
}

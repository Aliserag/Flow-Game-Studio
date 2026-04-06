// start_canary.cdc
// Starts a canary deploy — routes `pct`% of users to the new contract version.
// Run after deploying the canary contract to a separate account.

import ContractRouter from 0xCONTRACT_ROUTER_ADDRESS

transaction(contractName: String, canaryAddress: Address, productionAddress: Address, pct: UInt8) {
    prepare(signer: auth(Storage) &Account) {
        let admin = signer.storage.borrow<auth(ContractRouter.RouterAdmin) &ContractRouter.Admin>(
            from: ContractRouter.AdminStoragePath
        ) ?? panic("No ContractRouter admin")

        admin.startCanary(
            contractName: contractName,
            canaryAddress: canaryAddress,
            productionAddress: productionAddress,
            pct: pct
        )

        log("Canary started: ".concat(pct.toString()).concat("% of users will use canary ").concat(contractName))
    }
}

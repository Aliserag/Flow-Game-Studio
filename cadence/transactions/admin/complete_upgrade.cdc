// complete_upgrade.cdc
// Completes a canary upgrade — marks the canary as the new production address.
// Run after verifying canary health over the full canary period.
// After this, run `flow project deploy --update` to replace the actual on-chain contract.

import ContractRouter from 0xCONTRACT_ROUTER_ADDRESS

transaction(contractName: String) {
    prepare(signer: auth(Storage) &Account) {
        let admin = signer.storage.borrow<auth(ContractRouter.RouterAdmin) &ContractRouter.Admin>(
            from: ContractRouter.AdminStoragePath
        ) ?? panic("No ContractRouter admin")

        admin.completeUpgrade(contractName: contractName)

        log("Upgrade completed for: ".concat(contractName))
    }
}

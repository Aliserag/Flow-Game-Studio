import "EmergencyPause"

transaction(reason: String) {
    let adminRef: auth(EmergencyPause.Pauser) &EmergencyPause.Admin
    let signerAddress: Address

    prepare(signer: auth(BorrowValue) &Account) {
        self.signerAddress = signer.address
        self.adminRef = signer.storage.borrow<auth(EmergencyPause.Pauser) &EmergencyPause.Admin>(
            from: EmergencyPause.AdminStoragePath
        ) ?? panic("No EmergencyPause.Admin in storage")
    }

    execute {
        self.adminRef.pause(reason: reason, by: self.signerAddress)
        log("System PAUSED: ".concat(reason))
    }
}

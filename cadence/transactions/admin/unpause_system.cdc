import "EmergencyPause"

transaction {
    let adminRef: auth(EmergencyPause.Unpauser) &EmergencyPause.Admin
    let signerAddress: Address

    prepare(signer: auth(BorrowValue) &Account) {
        self.signerAddress = signer.address
        self.adminRef = signer.storage.borrow<auth(EmergencyPause.Unpauser) &EmergencyPause.Admin>(
            from: EmergencyPause.AdminStoragePath
        ) ?? panic("No EmergencyPause.Admin in storage")
    }

    execute {
        self.adminRef.unpause(by: self.signerAddress)
        log("System UNPAUSED")
    }
}

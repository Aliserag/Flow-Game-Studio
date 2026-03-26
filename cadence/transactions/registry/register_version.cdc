import "VersionRegistry"

transaction(name: String, version: String, network: String, codeHash: String, changelog: String) {
    let signerAddress: Address
    prepare(signer: auth(Storage) &Account) {
        self.signerAddress = signer.address
    }
    execute {
        VersionRegistry.register(
            name: name, version: version, network: network,
            codeHash: codeHash, changelog: changelog, deployer: self.signerAddress
        )
    }
}

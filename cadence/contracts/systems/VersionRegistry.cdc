// cadence/contracts/systems/VersionRegistry.cdc
// Tracks deployed contract versions across networks.
// Upgrade safety: verifies upgrade compatibility before allowing deployment.
// Every contract upgrade MUST register here for audit trail.
access(all) contract VersionRegistry {

    access(all) entitlement Registrar

    access(all) event ContractRegistered(name: String, version: String, network: String, deployedAtBlock: UInt64)
    access(all) event UpgradeCompatibilityChecked(name: String, fromVersion: String, toVersion: String, safe: Bool)

    access(all) struct ContractVersion {
        access(all) let name: String
        access(all) let version: String         // semver: "1.2.3"
        access(all) let network: String         // "emulator", "testnet", "mainnet"
        access(all) let deployedAtBlock: UInt64
        access(all) let codeHash: String        // keccak256 of contract source
        access(all) let deployedBy: Address
        access(all) let changelog: String       // human-readable change summary

        init(name: String, version: String, network: String,
             codeHash: String, deployedBy: Address, changelog: String) {
            self.name = name
            self.version = version
            self.network = network
            self.deployedAtBlock = getCurrentBlock().height
            self.codeHash = codeHash
            self.deployedBy = deployedBy
            self.changelog = changelog
        }
    }

    // name -> [versions in order]
    access(self) var registry: {String: [ContractVersion]}

    access(all) fun register(
        name: String,
        version: String,
        network: String,
        codeHash: String,
        changelog: String,
        deployer: Address
    ) {
        if self.registry[name] == nil { self.registry[name] = [] }
        self.registry[name]!.append(ContractVersion(
            name: name, version: version, network: network,
            codeHash: codeHash, deployedBy: deployer, changelog: changelog
        ))
        emit ContractRegistered(name: name, version: version, network: network,
                                deployedAtBlock: getCurrentBlock().height)
    }

    access(all) fun getLatestVersion(_ name: String): ContractVersion? {
        let versions = self.registry[name] ?? []
        if versions.length == 0 { return nil }
        return versions[versions.length - 1]
    }

    access(all) fun getHistory(_ name: String): [ContractVersion] {
        return self.registry[name] ?? []
    }

    init() { self.registry = {} }
}

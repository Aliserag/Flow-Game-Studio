// ContractRouter.cdc
// Routes a percentage of traffic to a "canary" contract version.
// Canary players are selected deterministically by address hash.
//
// Flow contract upgrade constraint: you cannot change field types or remove fields.
// This router pattern lets you test NEW LOGIC with an upgraded contract
// while the old version remains for the majority of players.
//
// Canary period: typically 24-48 hours before full upgrade.

import "EmergencyPause"

access(all) contract ContractRouter {

    access(all) entitlement RouterAdmin

    access(all) struct RouteConfig {
        access(all) var canaryAddress: Address     // Deployed canary contract address
        access(all) var productionAddress: Address  // Current production contract address
        access(all) var canaryPct: UInt8            // 0-100: % of users on canary
        access(all) var canaryStartBlock: UInt64
        access(all) var isActive: Bool

        init(canary: Address, production: Address, pct: UInt8) {
            self.canaryAddress = canary; self.productionAddress = production
            self.canaryPct = pct; self.canaryStartBlock = getCurrentBlock().height
            self.isActive = true
        }
    }

    access(all) var routes: {String: RouteConfig}  // contractName -> config
    access(all) let AdminStoragePath: StoragePath

    access(all) event CanaryStarted(contractName: String, canaryAddress: Address, pct: UInt8)
    access(all) event UpgradeCompleted(contractName: String, newAddress: Address)

    // Returns true if this player should use the canary version
    access(all) view fun isCanaryUser(player: Address, contractName: String): Bool {
        let config = ContractRouter.routes[contractName] ?? return false
        if !config.isActive || config.canaryPct == 0 { return false }
        // Deterministic assignment: hash(player || contractName) mod 100 < canaryPct
        let combined = player.toString().concat(contractName)
        let hash = HashAlgorithm.SHA3_256.hash(combined.utf8)
        let slot = UInt8(hash[0] % 100)
        return slot < config.canaryPct
    }

    // Returns the contract address the player should use
    access(all) view fun getContractAddress(player: Address, contractName: String): Address {
        let config = ContractRouter.routes[contractName] ?? panic("Unknown contract: ".concat(contractName))
        if ContractRouter.isCanaryUser(player: player, contractName: contractName) {
            return config.canaryAddress
        }
        return config.productionAddress
    }

    access(all) resource Admin {
        access(RouterAdmin) fun startCanary(
            contractName: String,
            canaryAddress: Address,
            productionAddress: Address,
            pct: UInt8
        ) {
            pre { pct <= 20: "Canary should not exceed 20% initially" }
            ContractRouter.routes[contractName] = RouteConfig(
                canary: canaryAddress, production: productionAddress, pct: pct
            )
            emit CanaryStarted(contractName: contractName, canaryAddress: canaryAddress, pct: pct)
        }

        access(RouterAdmin) fun increaseCanaryPct(contractName: String, newPct: UInt8) {
            pre { ContractRouter.routes[contractName] != nil: "No canary active" }
            ContractRouter.routes[contractName]!.canaryPct = newPct
        }

        access(RouterAdmin) fun completeUpgrade(contractName: String) {
            var config = ContractRouter.routes[contractName] ?? panic("No canary active")
            let newAddress = config.canaryAddress
            config.canaryPct = 100
            config.productionAddress = newAddress
            config.isActive = false
            ContractRouter.routes[contractName] = config
            emit UpgradeCompleted(contractName: contractName, newAddress: newAddress)
        }

        access(RouterAdmin) fun rollbackCanary(contractName: String) {
            ContractRouter.routes.remove(key: contractName)
        }
    }

    init() {
        self.routes = {}
        self.AdminStoragePath = /storage/ContractRouterAdmin
        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
    }
}

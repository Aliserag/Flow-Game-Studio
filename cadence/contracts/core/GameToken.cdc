// cadence/contracts/core/GameToken.cdc
// In-game fungible currency following FungibleToken v2 standard.
// Cadence 1.0 entitlements guard minting — only the Minter resource can create supply.
// Hard cap enforced at contract level. Burn is always available via Burner.burn().
//
// REGULATORY NOTE: Fungible tokens with real-world value may constitute securities
// in some jurisdictions. This contract is designed for in-game utility only.
// Consult legal counsel before enabling off-ramp to real-world currency.
import "FungibleToken"

access(all) contract GameToken: FungibleToken {

    // MintTokens entitlement — held only by the Minter resource stored at deployer account.
    // Named MintTokens (not Minter) to avoid collision with the Minter resource name.
    access(all) entitlement MintTokens

    // Fires once at contract deployment
    access(all) event TokensInitialized(initialSupply: UFix64)
    // Fires when new tokens are created by the Minter
    access(all) event TokensMinted(amount: UFix64, to: Address?)
    // Fires when tokens leave a vault via withdraw()
    access(all) event TokensWithdrawn(amount: UFix64, from: Address?)
    // Fires when tokens enter a vault via deposit()
    access(all) event TokensDeposited(amount: UFix64, to: Address?)

    // Readable by all; only decremented on burnCallback / incremented on mint
    access(all) var totalSupply: UFix64
    access(all) let maxSupply: UFix64
    access(all) let tokenName: String
    access(all) let tokenSymbol: String

    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultPublicPath: PublicPath
    access(all) let ReceiverPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    access(all) resource Vault: FungibleToken.Vault {
        access(all) var balance: UFix64

        // burnCallback is called by Burner.burn() — reduces totalSupply and zeroes balance
        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                GameToken.totalSupply = GameToken.totalSupply - self.balance
            }
            self.balance = 0.0
        }

        // FungibleToken.Withdraw is a standard entitlement defined in the FungibleToken contract
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @GameToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <- create Vault(balance: amount)
        }

        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @GameToken.Vault
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            self.balance = self.balance + vault.balance
            destroy vault
        }

        access(all) fun createEmptyVault(): @GameToken.Vault {
            return <- create Vault(balance: 0.0)
        }

        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return self.balance >= amount
        }

        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {self.getType(): true}
        }

        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return self.getSupportedVaultTypes()[type] ?? false
        }

        access(all) view fun getViews(): [Type] {
            return GameToken.getContractViews(resourceType: nil)
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return GameToken.resolveContractView(resourceType: nil, viewType: view)
        }

        init(balance: UFix64) { self.balance = balance }
    }

    // Minter resource — stored at deployer account, never published to public paths
    access(all) resource Minter {
        // mintTokens requires the MintTokens entitlement — only borrow with auth(GameToken.MintTokens)
        access(MintTokens) fun mintTokens(amount: UFix64): @GameToken.Vault {
            pre {
                GameToken.totalSupply + amount <= GameToken.maxSupply:
                    "Mint would exceed max supply of ".concat(GameToken.maxSupply.toString())
                amount > UFix64(0): "Cannot mint zero tokens"
            }
            GameToken.totalSupply = GameToken.totalSupply + amount
            emit TokensMinted(amount: amount, to: nil)
            return <- create Vault(balance: amount)
        }

        access(MintTokens) fun mintToRecipient(
            amount: UFix64,
            recipient: &{FungibleToken.Receiver}
        ) {
            let tokens <- self.mintTokens(amount: amount)
            emit TokensMinted(amount: amount, to: recipient.owner?.address)
            recipient.deposit(from: <- tokens)
        }
    }

    access(all) fun createEmptyVault(vaultType: Type): @GameToken.Vault {
        return <- create Vault(balance: 0.0)
    }

    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return []
    }

    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        return nil
    }

    init(tokenName: String, tokenSymbol: String, maxSupply: UFix64) {
        self.totalSupply = 0.0
        self.maxSupply = maxSupply
        self.tokenName = tokenName
        self.tokenSymbol = tokenSymbol
        self.VaultStoragePath = /storage/GameTokenVault
        self.VaultPublicPath = /public/GameTokenVault
        self.ReceiverPublicPath = /public/GameTokenReceiver
        self.MinterStoragePath = /storage/GameTokenMinter

        self.account.storage.save(<- create Minter(), to: self.MinterStoragePath)
        emit TokensInitialized(initialSupply: 0.0)
    }
}

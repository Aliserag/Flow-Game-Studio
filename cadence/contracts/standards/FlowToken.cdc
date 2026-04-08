import FungibleToken from "./FungibleToken.cdc"

/// FlowToken
///
/// The Flow Token contract
///
access(all) contract FlowToken: FungibleToken {

    /// Total supply of Flow tokens in existence
    access(all) var totalSupply: UFix64

    /// Event that is emitted when the contract is created
    access(all) event TokensInitialized(initialSupply: UFix64)

    /// Event that is emitted when tokens are withdrawn from a Vault
    access(all) event TokensWithdrawn(amount: UFix64, from: Address?)

    /// Event that is emitted when tokens are deposited to a Vault
    access(all) event TokensDeposited(amount: UFix64, to: Address?)

    /// Event that is emitted when new tokens are minted
    access(all) event TokensMinted(amount: UFix64)

    /// Event that is emitted when tokens are destroyed
    access(all) event TokensBurned(amount: UFix64)

    /// Storage and Public Paths
    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultPublicPath: PublicPath
    access(all) let ReceiverPublicPath: PublicPath
    access(all) let BalancePublicPath: PublicPath
    access(all) let AdminStoragePath: StoragePath

    /// Vault
    ///
    /// Each user stores an instance of only the Vault in their storage
    /// The functions in the Vault and governed by the pre and post conditions
    /// in FungibleToken when they are called.
    /// The checks happen at runtime whenever a function is called.
    ///
    access(all) resource Vault: FungibleToken.Vault, FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance {

        /// The total balance of this vault
        access(all) var balance: UFix64

        /// Initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
        }

        /// withdraw
        ///
        /// Function that takes an amount as an argument
        /// and withdraws that amount from the Vault.
        /// It creates a new temporary Vault that is used to hold
        /// the money that is being transferred. It returns the newly
        /// created Vault to the context that called so it can be deposited
        /// elsewhere.
        ///
        access(all) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        /// deposit
        ///
        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @FlowToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }
    }

    /// createEmptyVault
    ///
    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context. A user must call this function
    /// and store the returned Vault in their storage in order to allow their
    /// account to be able to receive deposits of this token type.
    ///
    access(all) fun createEmptyVault(vaultType: Type): @{FungibleToken.Vault} {
        return <-create Vault(balance: 0.0)
    }

    init() {
        self.totalSupply = 0.0

        self.VaultStoragePath = /storage/flowTokenVault
        self.VaultPublicPath = /public/flowTokenVault
        self.ReceiverPublicPath = /public/flowTokenReceiver
        self.BalancePublicPath = /public/flowTokenBalance
        self.AdminStoragePath = /storage/flowTokenAdmin

        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}

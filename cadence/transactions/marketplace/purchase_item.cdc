// cadence/transactions/marketplace/purchase_item.cdc
// Buyer pays the listed price and receives the NFT.
// Platform fee and royalties are deducted automatically by Marketplace.purchase().
import "FungibleToken"
import "NonFungibleToken"
import "GameToken"
import "GameNFT"
import "Marketplace"

transaction(listingId: UInt64) {
    let payment: @{FungibleToken.Vault}
    let buyerCollection: &{NonFungibleToken.Collection}
    let buyerAddress: Address

    prepare(buyer: auth(Storage) &Account) {
        let listing = Marketplace.getListing(listingId) ?? panic("Listing not found")

        let vault = buyer.storage.borrow<auth(FungibleToken.Withdraw) &GameToken.Vault>(
            from: GameToken.VaultStoragePath
        ) ?? panic("No GameToken Vault found — run setup_token_vault.cdc first")

        self.payment <- vault.withdraw(amount: listing.price)

        self.buyerCollection = buyer.storage.borrow<&GameNFT.Collection>(
            from: GameNFT.CollectionStoragePath
        ) ?? panic("No GameNFT Collection found — run setup_account.cdc first")

        self.buyerAddress = buyer.address
    }

    execute {
        Marketplace.purchase(
            listingId: listingId,
            payment: <- self.payment,
            buyer: self.buyerAddress,
            buyerCollection: self.buyerCollection
        )
    }
}

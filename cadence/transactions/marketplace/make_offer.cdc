// cadence/transactions/marketplace/make_offer.cdc
// Buyer makes an offer on a specific NFT ID. Tokens are escrowed in the
// Marketplace contract until the offer is accepted or cancelled.
import "FungibleToken"
import "GameToken"
import "Marketplace"

transaction(nftId: UInt64, amount: UFix64, validForBlocks: UInt64) {
    let payment: @{FungibleToken.Vault}
    let buyerAddress: Address

    prepare(buyer: auth(Storage) &Account) {
        let vault = buyer.storage.borrow<auth(FungibleToken.Withdraw) &GameToken.Vault>(
            from: GameToken.VaultStoragePath
        ) ?? panic("No GameToken Vault found — run setup_token_vault.cdc first")

        self.payment <- vault.withdraw(amount: amount)
        self.buyerAddress = buyer.address
    }

    execute {
        let offerId = Marketplace.makeOffer(
            nftId: nftId,
            payment: <- self.payment,
            buyer: self.buyerAddress,
            validForBlocks: validForBlocks
        )
        log("Offer #".concat(offerId.toString()).concat(" placed on NFT ").concat(nftId.toString()))
    }
}

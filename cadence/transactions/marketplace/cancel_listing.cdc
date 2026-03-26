// cadence/transactions/marketplace/cancel_listing.cdc
// Seller cancels their active listing and recovers the escrowed NFT.
import "NonFungibleToken"
import "GameNFT"
import "Marketplace"

transaction(listingId: UInt64) {
    let sellerCollection: &{NonFungibleToken.Collection}
    let sellerAddress: Address

    prepare(seller: auth(Storage) &Account) {
        self.sellerCollection = seller.storage.borrow<&GameNFT.Collection>(
            from: GameNFT.CollectionStoragePath
        ) ?? panic("No GameNFT Collection found in seller storage")

        self.sellerAddress = seller.address
    }

    execute {
        Marketplace.cancelListing(
            listingId: listingId,
            seller: self.sellerAddress,
            sellerCollection: self.sellerCollection
        )
    }
}

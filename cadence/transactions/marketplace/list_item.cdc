// cadence/transactions/marketplace/list_item.cdc
// Seller withdraws an NFT from their collection and lists it on the Marketplace.
// The NFT is escrowed in the Marketplace contract until purchased or cancelled.
import "NonFungibleToken"
import "GameNFT"
import "Marketplace"

transaction(nftId: UInt64, price: UFix64) {
    let nft: @{NonFungibleToken.NFT}
    let sellerAddress: Address

    prepare(seller: auth(Storage) &Account) {
        let collection = seller.storage.borrow<auth(NonFungibleToken.Withdraw) &GameNFT.Collection>(
            from: GameNFT.CollectionStoragePath
        ) ?? panic("No GameNFT Collection found in seller storage")

        self.nft <- collection.withdraw(withdrawID: nftId)
        self.sellerAddress = seller.address
    }

    execute {
        let listingId = Marketplace.listItem(
            nft: <- self.nft,
            price: price,
            seller: self.sellerAddress
        )
        log("Listed NFT ".concat(nftId.toString()).concat(" as listing #").concat(listingId.toString()))
    }
}

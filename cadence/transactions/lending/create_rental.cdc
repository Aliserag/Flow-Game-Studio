// Lender issues a capability for their NFT and registers the rental.
// The capability gives the borrower auth(GameNFT.Use) access — enough to
// use the NFT in-game but NOT to withdraw/transfer it.

import "NonFungibleToken"
import "GameNFT"
import "NFTLending"

transaction(
    nftId: UInt64,
    borrower: Address,
    durationBlocks: UInt64,
    collateralAmount: UFix64,
    pricePerEpoch: UFix64
) {
    let lenderAddress: Address

    prepare(lender: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability) &Account) {
        self.lenderAddress = lender.address

        // Verify lender owns the NFT
        let collection = lender.storage.borrow<&GameNFT.Collection>(
            from: GameNFT.CollectionStoragePath
        ) ?? panic("No GameNFT collection")
        assert(collection.ownedNFTs[nftId] != nil, message: "NFT not in collection")

        // Issue a capability with GameNFT.Use entitlement only (not Withdraw)
        // This lets the borrower use the NFT in game logic but not transfer it
        let cap = lender.capabilities.storage.issue<auth(GameNFT.Use) &GameNFT.NFT>(
            /storage/GameNFTCollection  // note: path to individual NFT via borrowNFT
        )
        let controllerID = cap.id

        // Publish the capability to a path the borrower can claim
        let pubPath = PublicPath(identifier: "rental_nft_".concat(nftId.toString()))!
        lender.capabilities.publish(cap, at: pubPath)

        // Register in the lending contract
        NFTLending.createRental(
            lender: self.lenderAddress,
            borrower: borrower,
            nftId: nftId,
            nftContractAddress: self.lenderAddress,
            collateralAmount: collateralAmount,
            pricePerEpoch: pricePerEpoch,
            durationBlocks: durationBlocks,
            capabilityControllerID: controllerID
        )
    }
}

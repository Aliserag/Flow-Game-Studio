// cadence/transactions/nft/burn_nft.cdc
// Permanently destroys an NFT from the signer's collection.
// This action is irreversible. Use with caution.
import "NonFungibleToken"
import "GameNFT"

transaction(nftId: UInt64) {
    prepare(signer: auth(Storage) &Account) {
        let collection = signer.storage.borrow<auth(NonFungibleToken.Withdraw) &GameNFT.Collection>(
            from: GameNFT.CollectionStoragePath
        ) ?? panic("No NFT collection found")
        let nft <- collection.withdraw(withdrawID: nftId)
        destroy nft
    }
}

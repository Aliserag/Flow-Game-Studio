// Attaches EquipmentAttachment.Equipment to the caller's NFT.
// Must be called before any equip operations.
// The attachment travels with the NFT if transferred.

import "NonFungibleToken"
import "GameNFT"
import "EquipmentAttachment"

transaction(nftId: UInt64) {

    prepare(signer: auth(BorrowValue, SaveValue) &Account) {
        let collection = signer.storage.borrow<auth(NonFungibleToken.Update) &GameNFT.Collection>(
            from: GameNFT.CollectionStoragePath
        ) ?? panic("No GameNFT collection")

        // Withdraw, attach, and re-store
        let nft <- collection.withdraw(withdrawID: nftId)

        // Only attach if not already present
        if nft[EquipmentAttachment.Equipment] == nil {
            let equipped <- attach EquipmentAttachment.Equipment() to <-nft
            collection.deposit(token: <-equipped)
        } else {
            collection.deposit(token: <-nft)
        }
    }
}

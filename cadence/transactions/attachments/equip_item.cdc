import "NonFungibleToken"
import "GameNFT"
import "EquipmentAttachment"

transaction(nftId: UInt64, slot: String, itemId: UInt64, itemName: String) {
    let signerAddress: Address

    prepare(signer: auth(BorrowValue) &Account) {
        self.signerAddress = signer.address
        let collection = signer.storage.borrow<auth(NonFungibleToken.Update) &GameNFT.Collection>(
            from: GameNFT.CollectionStoragePath
        ) ?? panic("No GameNFT collection")

        let nftRef = collection.borrowNFT(nftId)
            ?? panic("NFT not found: ".concat(nftId.toString()))

        // Access the attachment with the Equip entitlement
        let equipment = nftRef[EquipmentAttachment.Equipment]
            ?? panic("No EquipmentAttachment on this NFT — run attach_equipment_slot first")

        // The attachment reference gives Equip access because we own the NFT
        // and borrowNFT returns auth(EquipmentAttachment.Equip) &EquipmentAttachment.Equipment
        equipment.equip(slot: slot, itemId: itemId, itemName: itemName)
    }
}

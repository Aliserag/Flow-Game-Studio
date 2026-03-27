import "NonFungibleToken"
import "GameNFT"
import "BuffAttachment"

// apply_buff.cdc — Apply a time-limited buff to an NFT.
// Must be called by an authorized system (not directly by players).
transaction(nftId: UInt64, ownerAddress: Address, buffType: String, magnitude: UFix64, durationBlocks: UInt64, source: String) {

    prepare(signer: auth(BorrowValue) &Account) {
        // Borrow the target NFT from the owner's collection
        let collection = getAccount(ownerAddress).storage
            .borrow<&GameNFT.Collection>(from: GameNFT.CollectionStoragePath)
            ?? panic("No GameNFT collection for owner")

        let nftRef = collection.borrowNFT(nftId)
            ?? panic("NFT not found: ".concat(nftId.toString()))

        let buffs = nftRef[BuffAttachment.Buffs]
            ?? panic("No BuffAttachment on this NFT")

        buffs.applyBuff(
            buffType: buffType,
            magnitude: magnitude,
            durationBlocks: durationBlocks,
            source: source
        )
    }
}

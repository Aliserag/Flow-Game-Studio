// claim_nft_from_child.cdc
// Allows a parent account (player's wallet) to withdraw an NFT
// from their linked child account (game-managed account).
//
// The player signs this with their own wallet — no game server involvement.

import HybridCustody from 0xHYBRID_CUSTODY_ADDRESS
import GameNFT from 0xGAME_NFT_ADDRESS
import NonFungibleToken from 0xNON_FUNGIBLE_TOKEN_ADDRESS

transaction(childAddress: Address, nftId: UInt64) {
    prepare(parent: auth(Storage) &Account) {
        // Get the parent's HybridCustody manager
        let manager = parent.storage.borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(
            from: HybridCustody.ManagerStoragePath
        ) ?? panic("No HybridCustody manager — run setup first")

        // Get the child account reference
        let childAcct = manager.borrowAccount(addr: childAddress)
            ?? panic("No child account found at ".concat(childAddress.toString()))

        // Borrow the child's NFT collection with Withdraw entitlement
        let childCollection = childAcct.getCapability(
            controllerID: 0,  // Replace with actual capability controller ID
            type: Type<auth(GameNFT.Withdraw) &GameNFT.Collection>()
        ) as! Capability<auth(GameNFT.Withdraw) &GameNFT.Collection>

        let collectionRef = childCollection.borrow()
            ?? panic("Could not borrow child's NFT collection")

        // Withdraw from child
        let nft <- collectionRef.withdraw(withdrawID: nftId)

        // Deposit into parent's collection
        let parentCollection = parent.storage.borrow<&GameNFT.Collection>(
            from: /storage/GameNFTCollection
        ) ?? panic("No GameNFT collection in parent account — run setup first")

        parentCollection.deposit(token: <-nft)

        log("NFT claimed from child account")
    }
}

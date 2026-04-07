import "FungibleToken"
import "FlowToken"
import "CoinFlip"

transaction(id: UInt64) {
    let adminRef: &CoinFlip.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        self.adminRef = signer.storage.borrow<&CoinFlip.Admin>(from: /storage/CoinFlipGameManager)
            ?? panic("Signer is not the admin — CoinFlipGameManager not found")
    }

    execute {
        self.adminRef.tossCoin(id: id)
    }
}

// examples/chess-game/cadence/transactions/setup_chess_account.cdc
import NonFungibleToken from "NonFungibleToken"
import ChessPiece from "ChessPiece"

transaction {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        if signer.storage.borrow<&ChessPiece.Collection>(from: ChessPiece.CollectionStoragePath) == nil {
            let collection <- ChessPiece.createEmptyCollection(nftType: Type<@ChessPiece.NFT>())
            signer.storage.save(<- collection, to: ChessPiece.CollectionStoragePath)
            let cap = signer.capabilities.storage.issue<&ChessPiece.Collection>(ChessPiece.CollectionStoragePath)
            signer.capabilities.publish(cap, at: ChessPiece.CollectionPublicPath)
        }
    }
}

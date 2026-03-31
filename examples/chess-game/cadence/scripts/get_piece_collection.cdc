import ChessPiece from "ChessPiece"
access(all) fun main(addr: Address): [UInt64] {
    let collection = getAccount(addr)
        .capabilities.borrow<&ChessPiece.Collection>(ChessPiece.CollectionPublicPath)
        ?? return []
    return collection.getIDs()
}

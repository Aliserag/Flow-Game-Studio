import ChessPiece from "ChessPiece"
import ChessStatsAttachment from "ChessStatsAttachment"
access(all) fun main(addr: Address, pieceId: UInt64): {String: UInt64}? {
    let collection = getAccount(addr)
        .capabilities.borrow<&ChessPiece.Collection>(ChessPiece.CollectionPublicPath)
        ?? return nil
    let piece = collection.borrowChessPiece(pieceId) ?? return nil
    let stats = piece[ChessStatsAttachment.Stats] ?? return nil
    return {
        "movesMade": stats.movesMade,
        "capturesMade": stats.capturesMade,
        "timesCheckedKing": stats.timesCheckedKing,
        "gamesWon": stats.gamesWon,
        "gamesLost": stats.gamesLost
    }
}

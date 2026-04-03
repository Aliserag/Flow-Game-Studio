// examples/chess-game/cadence/contracts/ChessPiece.cdc
import NonFungibleToken from "NonFungibleToken"
import MetadataViews from "MetadataViews"
import ViewResolver from "ViewResolver"

access(all) contract ChessPiece: NonFungibleToken, ViewResolver {

    access(all) var totalSupply: UInt64

    access(all) event ContractInitialized()
    access(all) event Withdraw(id: UInt64, from: Address?)
    access(all) event Deposit(id: UInt64, to: Address?)
    access(all) event PieceMinted(id: UInt64, pieceType: UInt8, color: UInt8, gameId: UInt64)

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    access(all) entitlement Minter
    access(all) entitlement GameUpdater

    access(all) enum PieceType: UInt8 {
        access(all) case King
        access(all) case Queen
        access(all) case Rook
        access(all) case Bishop
        access(all) case Knight
        access(all) case Pawn
    }

    access(all) enum PieceColor: UInt8 {
        access(all) case White
        access(all) case Black
    }

    access(all) resource NFT: NonFungibleToken.NFT, ViewResolver.Resolver {
        access(all) let id: UInt64
        access(all) let pieceType: PieceType
        access(all) let color: PieceColor
        access(all) let symbol: String
        access(all) let gameId: UInt64
        access(all) let startSquare: String

        init(id: UInt64, pieceType: PieceType, color: PieceColor, gameId: UInt64, startSquare: String) {
            self.id = id
            self.pieceType = pieceType
            self.color = color
            self.gameId = gameId
            self.startSquare = startSquare
            self.symbol = ChessPiece.symbolFor(pieceType: pieceType, color: color)
        }

        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.NFTCollectionData>()
            ]
        }

        access(all) view fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    let colorName = self.color == ChessPiece.PieceColor.White ? "White" : "Black"
                    let typeName = ChessPiece.typeNameFor(pieceType: self.pieceType)
                    return MetadataViews.Display(
                        name: colorName.concat(" ").concat(typeName),
                        description: "A ".concat(colorName).concat(" ").concat(typeName).concat(" chess piece from game #").concat(self.gameId.toString()),
                        thumbnail: MetadataViews.HTTPFile(url: "https://chess-on-flow.example/pieces/".concat(self.symbol))
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.id)
                case Type<MetadataViews.Traits>():
                    let colorName = self.color == ChessPiece.PieceColor.White ? "White" : "Black"
                    let typeName = ChessPiece.typeNameFor(pieceType: self.pieceType)
                    let traits: [MetadataViews.Trait] = [
                        MetadataViews.Trait(name: "pieceType", value: typeName, displayType: "String", rarity: nil),
                        MetadataViews.Trait(name: "color", value: colorName, displayType: "String", rarity: nil),
                        MetadataViews.Trait(name: "gameId", value: self.gameId, displayType: "Number", rarity: nil)
                    ]
                    return MetadataViews.Traits(traits)
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: ChessPiece.CollectionStoragePath,
                        publicPath: ChessPiece.CollectionPublicPath,
                        publicCollection: Type<&ChessPiece.Collection>(),
                        publicLinkedType: Type<&ChessPiece.Collection>(),
                        createEmptyCollectionFunction: fun(): @{NonFungibleToken.Collection} {
                            return <- ChessPiece.createEmptyCollection(nftType: Type<@ChessPiece.NFT>())
                        }
                    )
            }
            return nil
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- ChessPiece.createEmptyCollection(nftType: Type<@ChessPiece.NFT>())
        }

        // GameUpdater entitlement support: required so attachments (e.g. ChessStatsAttachment)
        // can declare members with access(GameUpdater) against this base type.
        access(GameUpdater) fun _gameUpdaterSupport() {}
    }

    access(all) resource Collection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: {NonFungibleToken.NFT}}

        init() { self.ownedNFTs <- {} }

        access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("ChessPiece: NFT ".concat(withdrawID.toString()).concat(" not found"))
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let piece <- token as! @ChessPiece.NFT
            emit Deposit(id: piece.id, to: self.owner?.address)
            self.ownedNFTs[piece.id] <-! piece
        }

        access(all) view fun getIDs(): [UInt64] { return self.ownedNFTs.keys }

        access(all) view fun getLength(): Int { return self.ownedNFTs.length }

        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        access(all) fun borrowChessPiece(_ id: UInt64): &ChessPiece.NFT? {
            let ref = &self.ownedNFTs[id] as &{NonFungibleToken.NFT}?
            return ref as! &ChessPiece.NFT?
        }

        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            return {Type<@ChessPiece.NFT>(): true}
        }

        access(all) view fun isSupportedNFTType(type: Type): Bool {
            return type == Type<@ChessPiece.NFT>()
        }

        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- ChessPiece.createEmptyCollection(nftType: Type<@ChessPiece.NFT>())
        }
    }

    access(all) resource NFTMinter {
        access(Minter) fun mintPiece(pieceType: PieceType, color: PieceColor, gameId: UInt64, startSquare: String): @NFT {
            let id = ChessPiece.totalSupply
            ChessPiece.totalSupply = ChessPiece.totalSupply + 1
            emit PieceMinted(id: id, pieceType: pieceType.rawValue, color: color.rawValue, gameId: gameId)
            return <- create NFT(id: id, pieceType: pieceType, color: color, gameId: gameId, startSquare: startSquare)
        }
    }

    access(all) fun createEmptyCollection(nftType: Type): @{NonFungibleToken.Collection} {
        return <- create Collection()
    }

    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [Type<MetadataViews.NFTCollectionData>()]
    }

    access(all) view fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                    storagePath: ChessPiece.CollectionStoragePath,
                    publicPath: ChessPiece.CollectionPublicPath,
                    publicCollection: Type<&ChessPiece.Collection>(),
                    publicLinkedType: Type<&ChessPiece.Collection>(),
                    createEmptyCollectionFunction: fun(): @{NonFungibleToken.Collection} {
                        return <- ChessPiece.createEmptyCollection(nftType: Type<@ChessPiece.NFT>())
                    }
                )
        }
        return nil
    }

    access(all) view fun symbolFor(pieceType: PieceType, color: PieceColor): String {
        if color == PieceColor.White {
            switch pieceType {
                case PieceType.King:   return "\u{2654}"
                case PieceType.Queen:  return "\u{2655}"
                case PieceType.Rook:   return "\u{2656}"
                case PieceType.Bishop: return "\u{2657}"
                case PieceType.Knight: return "\u{2658}"
                case PieceType.Pawn:   return "\u{2659}"
            }
        } else {
            switch pieceType {
                case PieceType.King:   return "\u{265A}"
                case PieceType.Queen:  return "\u{265B}"
                case PieceType.Rook:   return "\u{265C}"
                case PieceType.Bishop: return "\u{265D}"
                case PieceType.Knight: return "\u{265E}"
                case PieceType.Pawn:   return "\u{265F}"
            }
        }
        return "?"
    }

    access(all) view fun typeNameFor(pieceType: PieceType): String {
        switch pieceType {
            case PieceType.King:   return "King"
            case PieceType.Queen:  return "Queen"
            case PieceType.Rook:   return "Rook"
            case PieceType.Bishop: return "Bishop"
            case PieceType.Knight: return "Knight"
            case PieceType.Pawn:   return "Pawn"
        }
        return "Unknown"
    }

    init() {
        self.totalSupply = 0
        self.CollectionStoragePath = /storage/chessCollection
        self.CollectionPublicPath = /public/chessCollection
        self.MinterStoragePath = /storage/chessMinter

        let minter <- create NFTMinter()
        self.account.storage.save(<- minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}

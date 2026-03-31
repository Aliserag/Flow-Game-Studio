// examples/chess-game/cadence/contracts/ChessStatsAttachment.cdc
import NonFungibleToken from "NonFungibleToken"
import ChessPiece from "ChessPiece"

access(all) contract ChessStatsAttachment {

    access(all) event StatsUpdated(pieceId: UInt64, movesMade: UInt64, capturesMade: UInt64)

    access(all) attachment Stats for ChessPiece.NFT {
        access(all) var movesMade: UInt64
        access(all) var capturesMade: UInt64
        access(all) var timesCheckedKing: UInt64
        access(all) var gamesWon: UInt64
        access(all) var gamesLost: UInt64

        init() {
            self.movesMade = 0
            self.capturesMade = 0
            self.timesCheckedKing = 0
            self.gamesWon = 0
            self.gamesLost = 0
        }

        access(ChessPiece.GameUpdater) fun recordMove() {
            self.movesMade = self.movesMade + 1
        }

        access(ChessPiece.GameUpdater) fun recordCapture() {
            self.capturesMade = self.capturesMade + 1
            emit StatsUpdated(pieceId: self.base.id, movesMade: self.movesMade, capturesMade: self.capturesMade)
        }

        access(ChessPiece.GameUpdater) fun recordCheck() {
            self.timesCheckedKing = self.timesCheckedKing + 1
        }

        access(ChessPiece.GameUpdater) fun recordWin() {
            self.gamesWon = self.gamesWon + 1
        }

        access(ChessPiece.GameUpdater) fun recordLoss() {
            self.gamesLost = self.gamesLost + 1
        }
    }

    access(all) fun attachStats(to nft: auth(ChessPiece.GameUpdater) &ChessPiece.NFT) {
        if nft[Stats] == nil {
            attach Stats() to nft
        }
    }
}

import * as fcl from '@onflow/fcl'
import { sponsoredMutate, waitForSealed } from './sponsorship'

const CHESS_GAME_ADDRESS = '0xf8d6e0586b0a20c7'
const CHESS_PIECE_ADDRESS = '0xf8d6e0586b0a20c7'
const NFT_ADDRESS = '0xf8d6e0586b0a20c7'

export async function getBoard(gameId: number): Promise<Record<string, unknown> | null> {
  return fcl.query({
    cadence: `
      import ChessGame from ${CHESS_GAME_ADDRESS}
      access(all) fun main(gameId: UInt64): {String: AnyStruct}? {
        let game = ChessGame.getGame(gameId) ?? return nil
        return {
          "fen": game.fen,
          "lastMove": game.moveHistory.length > 0 ? game.moveHistory[game.moveHistory.length - 1] : "",
          "status": game.status.rawValue,
          "white": game.white,
          "black": game.black,
          "winner": game.winner
        }
      }
    `,
    args: (arg: typeof fcl.arg, t: typeof fcl.t) => [arg(gameId.toString(), t.UInt64)]
  })
}

export async function getActiveGames(address: string): Promise<number[]> {
  return fcl.query({
    cadence: `
      import ChessGame from ${CHESS_GAME_ADDRESS}
      access(all) fun main(addr: Address): [UInt64] {
        return ChessGame.getActiveGamesForAddress(addr)
      }
    `,
    args: (arg: typeof fcl.arg, t: typeof fcl.t) => [arg(address, t.Address)]
  })
}

export async function setupAccount(): Promise<void> {
  const txId = await sponsoredMutate({
    cadence: `
      import NonFungibleToken from ${NFT_ADDRESS}
      import ChessPiece from ${CHESS_PIECE_ADDRESS}
      transaction {
        prepare(signer: auth(Storage, Capabilities) &Account) {
          if signer.storage.borrow<&ChessPiece.Collection>(from: ChessPiece.CollectionStoragePath) == nil {
            let col <- ChessPiece.createEmptyCollection(nftType: Type<@ChessPiece.NFT>())
            signer.storage.save(<- col, to: ChessPiece.CollectionStoragePath)
            let cap = signer.capabilities.storage.issue<&ChessPiece.Collection>(ChessPiece.CollectionStoragePath)
            signer.capabilities.publish(cap, at: ChessPiece.CollectionPublicPath)
          }
        }
      }
    `
  })
  await waitForSealed(txId)
}

export async function createChallenge(opponentAddress: string): Promise<void> {
  const txId = await sponsoredMutate({
    cadence: `
      import ChessGame from ${CHESS_GAME_ADDRESS}
      transaction(opponent: Address) {
        prepare(signer: auth(Storage) &Account) {
          let _ = ChessGame.createChallenge(challenger: signer.address, opponent: opponent)
        }
      }
    `,
    args: (arg: typeof fcl.arg, t: typeof fcl.t) => [arg(opponentAddress, t.Address)]
  })
  await waitForSealed(txId)
}

export async function acceptAndReveal(gameId: number, secret: string): Promise<void> {
  const acceptId = await sponsoredMutate({
    cadence: `
      import ChessGame from ${CHESS_GAME_ADDRESS}
      transaction(gameId: UInt64, secret: UInt256) {
        prepare(signer: auth(Storage) &Account) {
          ChessGame.acceptChallenge(gameId: gameId, caller: signer.address, secret: secret)
        }
      }
    `,
    args: (arg: typeof fcl.arg, t: typeof fcl.t) => [arg(gameId.toString(), t.UInt64), arg(secret, t.UInt256)]
  })
  await waitForSealed(acceptId)

  const revealId = await sponsoredMutate({
    cadence: `
      import ChessGame from ${CHESS_GAME_ADDRESS}
      transaction(gameId: UInt64, secret: UInt256) {
        prepare(signer: auth(Storage) &Account) {
          ChessGame.revealColors(gameId: gameId, caller: signer.address, secret: secret)
        }
      }
    `,
    args: (arg: typeof fcl.arg, t: typeof fcl.t) => [arg(gameId.toString(), t.UInt64), arg(secret, t.UInt256)]
  })
  await waitForSealed(revealId)
}

export async function makeMove(gameId: number, move: string, newFen: string, isCapture: boolean, isCheck: boolean): Promise<void> {
  const txId = await sponsoredMutate({
    cadence: `
      import ChessGame from ${CHESS_GAME_ADDRESS}
      transaction(gameId: UInt64, move: String, newFen: String, isCapture: Bool, isCheck: Bool) {
        prepare(signer: auth(Storage) &Account) {
          ChessGame.makeMove(gameId: gameId, caller: signer.address, move: move, newFen: newFen, isCapture: isCapture, isCheck: isCheck)
        }
      }
    `,
    args: (arg: typeof fcl.arg, t: typeof fcl.t) => [
      arg(gameId.toString(), t.UInt64),
      arg(move, t.String),
      arg(newFen, t.String),
      arg(isCapture, t.Bool),
      arg(isCheck, t.Bool)
    ]
  })
  await waitForSealed(txId)
}

export async function resign(gameId: number): Promise<void> {
  const txId = await sponsoredMutate({
    cadence: `
      import ChessGame from ${CHESS_GAME_ADDRESS}
      transaction(gameId: UInt64) {
        prepare(signer: auth(Storage) &Account) {
          ChessGame.resign(gameId: gameId, caller: signer.address)
        }
      }
    `,
    args: (arg: typeof fcl.arg, t: typeof fcl.t) => [arg(gameId.toString(), t.UInt64)]
  })
  await waitForSealed(txId)
}

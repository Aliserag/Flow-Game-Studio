import { Chess } from 'chess.js'

const WHITE_PIECES: Record<string, string> = {
  k: '♔', q: '♕', r: '♖', b: '♗', n: '♘', p: '♙'
}
const BLACK_PIECES: Record<string, string> = {
  k: '♚', q: '♛', r: '♜', b: '♝', n: '♞', p: '♟'
}

export interface BoardState {
  fen: string
  chess: Chess
  selectedSquare: string | null
  validMoves: string[]
  isWhitePerspective: boolean
}

export function createBoardState(fen: string, isWhite: boolean): BoardState {
  return { fen, chess: new Chess(fen), selectedSquare: null, validMoves: [], isWhitePerspective: isWhite }
}

export function renderBoard(state: BoardState, container: HTMLElement): void {
  container.innerHTML = ''
  container.className = 'chess-board'
  const board = state.chess.board()
  const ranks = state.isWhitePerspective ? [7, 6, 5, 4, 3, 2, 1, 0] : [0, 1, 2, 3, 4, 5, 6, 7]
  const files = state.isWhitePerspective ? [0, 1, 2, 3, 4, 5, 6, 7] : [7, 6, 5, 4, 3, 2, 1, 0]

  for (const rankIdx of ranks) {
    for (const fileIdx of files) {
      const square = document.createElement('div')
      const isLight = (rankIdx + fileIdx) % 2 === 1
      const squareName = String.fromCharCode(97 + fileIdx) + (rankIdx + 1)
      square.className = `square ${isLight ? 'light' : 'dark'}`
      square.dataset.square = squareName
      if (state.selectedSquare === squareName) square.classList.add('selected')
      if (state.validMoves.includes(squareName)) square.classList.add('valid-move')
      const piece = board[7 - rankIdx]?.[fileIdx]
      if (piece) {
        const pieceEl = document.createElement('span')
        pieceEl.className = 'piece'
        pieceEl.textContent = piece.color === 'w' ? WHITE_PIECES[piece.type] : BLACK_PIECES[piece.type]
        square.appendChild(pieceEl)
      }
      container.appendChild(square)
    }
  }
}

export function getValidMoveTargets(chess: Chess, square: string): string[] {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const moves = chess.moves({ square: square as any, verbose: true })
  return (moves as Array<{to: string}>).map(m => m.to)
}

export function applyMove(state: BoardState, from: string, to: string): { newFen: string; isCapture: boolean; isCheck: boolean; move: string } | null {
  const chess = new Chess(state.fen)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const move = chess.move({ from: from as any, to: to as any, promotion: 'q' })
  if (!move) return null
  return {
    newFen: chess.fen(),
    isCapture: move.flags.includes('c') || move.flags.includes('e'),
    isCheck: chess.inCheck(),
    move: move.san
  }
}

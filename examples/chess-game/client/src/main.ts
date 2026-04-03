import * as fcl from '@onflow/fcl'
import { configureFCL, getCurrentUser } from './wallet'
import { renderBoard, createBoardState, getValidMoveTargets, applyMove } from './board'
import { getBoard, makeMove, createChallenge, setupAccount, resign, getActiveGames, acceptAndReveal } from './chess-client'
import { chessAudio } from './audio'
import { Chess } from 'chess.js'

configureFCL()

let currentGameId: number | null = null
let myAddress: string | null = null
let myColor: 'w' | 'b' | null = null
let boardState = createBoardState('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', true)
let pollInterval: ReturnType<typeof setInterval> | null = null

const boardEl = document.getElementById('board')!
const statusEl = document.getElementById('status')!
const muteBtn = document.getElementById('mute-btn')!

function updateStatus(msg: string): void {
  statusEl.textContent = msg
}

async function pollBoard(): Promise<void> {
  if (currentGameId === null) return
  try {
    const data = await getBoard(currentGameId)
    if (!data) return
    const newFen = data['fen'] as string
    if (newFen !== boardState.fen) {
      boardState = createBoardState(newFen, myColor === 'w')
      renderBoard(boardState, boardEl)
      bindSquareClicks()
      const chess = new Chess(newFen)
      if (chess.isCheckmate()) {
        chessAudio.playCheckmate()
        updateStatus(`Checkmate! Winner: ${data['winner']}`)
      } else if (chess.inCheck()) {
        chessAudio.playCheck()
      }
      const moveListEl = document.getElementById('move-list')
      if (moveListEl && data['moveHistory']) {
        const history = data['moveHistory'] as string[]
        moveListEl.textContent = ''
        history.forEach((m, i) => {
          const moveNum = Math.floor(i / 2) + 1
          const isWhiteMove = i % 2 === 0
          const span = document.createElement('span')
          span.textContent = isWhiteMove ? `${moveNum}. ${m} ` : `${m} `
          moveListEl.appendChild(span)
        })
      }
    }
    const statusMap: Record<number, string> = { 0: 'Pending', 1: 'Active', 2: 'Checkmate', 3: 'Stalemate', 4: 'Resigned', 5: 'Drawn', 6: 'Timed Out' }
    const chess = new Chess(newFen)
    updateStatus(`${statusMap[data['status'] as number] ?? 'Unknown'} — ${chess.turn() === 'w' ? 'White' : 'Black'} to move`)
  } catch (e) {
    console.error('Poll error:', e)
  }
}

function bindSquareClicks(): void {
  boardEl.querySelectorAll<HTMLElement>('.square').forEach(sq => {
    sq.addEventListener('click', async () => {
      const squareName = sq.dataset.square!
      const chess = boardState.chess

      if (boardState.selectedSquare === null) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const piece = chess.get(squareName as any)
        if (!piece) return
        const isMyTurn = (chess.turn() === 'w' && myColor === 'w') || (chess.turn() === 'b' && myColor === 'b')
        if (!isMyTurn || piece.color !== myColor) return
        boardState.selectedSquare = squareName
        boardState.validMoves = getValidMoveTargets(chess, squareName)
        renderBoard(boardState, boardEl)
        bindSquareClicks()
      } else {
        const from = boardState.selectedSquare
        boardState.selectedSquare = null
        boardState.validMoves = []
        if (squareName === from) { renderBoard(boardState, boardEl); bindSquareClicks(); return }

        const result = applyMove(boardState, from, squareName)
        if (!result) { renderBoard(boardState, boardEl); bindSquareClicks(); return }

        const newState = createBoardState(result.newFen, myColor === 'w')
        renderBoard(newState, boardEl)
        if (result.isCapture) chessAudio.playCapture()
        else chessAudio.playMove()

        try {
          updateStatus('Submitting move...')
          await makeMove(currentGameId!, result.move, result.newFen, result.isCapture, result.isCheck)
          boardState = newState
          bindSquareClicks()
          if (result.isCheck) {
            const c = new Chess(result.newFen)
            if (c.isCheckmate()) { chessAudio.playCheckmate(); updateStatus('Checkmate! You win!') }
            else { chessAudio.playCheck(); updateStatus('Check!') }
          }
        } catch (e) {
          renderBoard(boardState, boardEl)
          bindSquareClicks()
          updateStatus(`Move failed: ${e}`)
        }
      }
    })
  })
}

muteBtn.addEventListener('click', () => {
  const muted = !chessAudio.isMuted()
  chessAudio.setMuted(muted)
  muteBtn.textContent = muted ? '🔇' : '🔊'
})

getCurrentUser().subscribe(async (user: { addr?: string }) => {
  if (user.addr) {
    myAddress = user.addr
    try { await setupAccount(); updateStatus(`Connected: ${user.addr}`) }
    catch (e) { updateStatus(`Account setup: ${e}`) }
  } else {
    myAddress = null
    updateStatus('Not connected')
  }
})

function startGame(gameId: number, color: 'w' | 'b'): void {
  currentGameId = gameId
  myColor = color
  boardState = createBoardState('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', color === 'w')
  renderBoard(boardState, boardEl)
  bindSquareClicks()
  if (pollInterval) clearInterval(pollInterval)
  pollInterval = setInterval(pollBoard, 3000)
}

async function challenge(opponentAddr: string): Promise<void> {
  if (!myAddress) { updateStatus('Connect wallet first'); return }
  if (!opponentAddr) { updateStatus('Enter opponent address'); return }
  try {
    updateStatus('Creating challenge...')
    await createChallenge(opponentAddr)
    // Query active games to surface the new gameId to share with the opponent
    const games = await getActiveGames(myAddress!)
    const gameId = games.length > 0 ? games[games.length - 1] : null
    if (gameId !== null) {
      updateStatus(`Challenge created! Game ID: ${gameId} — share with opponent`)
    } else {
      updateStatus('Challenge created! Waiting for opponent...')
    }
  } catch (e) { updateStatus(`Challenge failed: ${e}`) }
}

async function acceptChallenge(gameIdStr: string): Promise<void> {
  if (!myAddress) { updateStatus('Connect wallet first'); return }
  const gameId = parseInt(gameIdStr, 10)
  if (isNaN(gameId)) { updateStatus('Enter a valid game ID'); return }
  try {
    updateStatus('Accepting challenge...')
    // Generate a 256-bit cryptographically secure random secret
    const randomBytes = new Uint8Array(32)
    crypto.getRandomValues(randomBytes)
    const secret = Array.from(randomBytes).reduce((acc, b) => acc * 256n + BigInt(b), 0n).toString()
    await acceptAndReveal(gameId, secret)

    // Poll until board shows assigned colors (Access Node may lag behind execution)
    let boardData: Record<string, unknown> | null = null
    for (let attempt = 0; attempt < 10; attempt++) {
      boardData = await getBoard(gameId)
      if (boardData && boardData['white'] && boardData['black']) break
      await new Promise(resolve => setTimeout(resolve, 500))
    }
    if (!boardData || !boardData['white']) {
      updateStatus(`Game ${gameId} started! Colors pending — refresh to see assignment`)
      startGame(gameId, 'w') // default to white pending refresh
      return
    }
    const isWhite = (boardData['white'] as string) === myAddress
    startGame(gameId, isWhite ? 'w' : 'b')
    updateStatus(`Game ${gameId} started! You are ${isWhite ? 'White' : 'Black'}`)
  } catch (e) { updateStatus(`Accept failed: ${e}`) }
}

async function resignGame(): Promise<void> {
  if (currentGameId === null) return
  try { await resign(currentGameId); updateStatus('You resigned.') }
  catch (e) { updateStatus(`Resign failed: ${e}`) }
}

renderBoard(boardState, boardEl)
bindSquareClicks()

// Suppress unused variable warnings — these are intentionally exposed on window
void myAddress

// Bind Connect Wallet button directly (inline onclick can't access ESM imports)
document.getElementById('connect-btn')?.addEventListener('click', () => (fcl as unknown as { authenticate: () => void }).authenticate())

;(window as unknown as Record<string, unknown>).chessApp = { startGame, challenge, acceptChallenge, resignGame, setupAccount, createChallenge }

import React, { useState } from 'react'
import ReactModal from 'react-modal'
import Confetti from 'react-confetti'
import { useWindowSize } from 'react-use'

interface Winner {
  id: number
  result: string
  timestamp: string
  hash: string
  amount: number
  isRevealed: boolean
  bet: string
  winnings: number
}

const MOCK_WINNERS: Winner[] = [
  { id: 1, result: 'HEADS', timestamp: 'APR 7, 2025 08:13:04 A.M.', hash: '0x43hj44930ffs', amount: 389, isRevealed: true, bet: 'HEADS', winnings: 0 },
  { id: 2, result: 'TAILS', timestamp: 'APR 7, 2025 08:10:11 A.M.', hash: '0x47dk32910ksd', amount: 292, isRevealed: false, bet: 'TAILS', winnings: 584 },
  { id: 3, result: 'HEADS', timestamp: 'APR 6, 2025 07:04:09 P.M.', hash: '0x94dj32197dd3', amount: 560, isRevealed: true, bet: 'TAILS', winnings: 0 },
  { id: 4, result: 'TAILS', timestamp: 'APR 6, 2025 06:13:04 P.M.', hash: '0x23ff44930lls', amount: 405, isRevealed: false, bet: 'TAILS', winnings: 810 },
  { id: 5, result: 'HEADS', timestamp: 'APR 5, 2025 09:15:00 A.M.', hash: '0x55gj44930ffr', amount: 350, isRevealed: true, bet: 'HEADS', winnings: 0 },
]

const PreviousWinners = () => {
  const [winners, setWinners] = useState<Winner[]>(MOCK_WINNERS)
  const [modalOpen, setModalOpen] = useState(false)
  const [rolling, setRolling] = useState(false)
  const [confetti, setConfetti] = useState(false)
  const [sadEmoji, setSadEmoji] = useState('')
  const [selectedId, setSelectedId] = useState<number | null>(null)
  const { width, height } = useWindowSize()
  const emojis = ['😔', '😭', '🪦', '🤬']

  const handleResultClick = (id: number) => {
    setSelectedId(id)
    setRolling(true)
    setTimeout(() => {
      setWinners(prev => prev.map(w => w.id === id ? { ...w, isRevealed: true } : w))
      setRolling(false)
      const winner = winners.find(w => w.id === id)
      if (winner?.bet === winner?.result) {
        setConfetti(true)
        setTimeout(() => setConfetti(false), 3000)
      } else {
        setSadEmoji(emojis[Math.floor(Math.random() * emojis.length)])
        setTimeout(() => setSadEmoji(''), 3000)
      }
    }, 3000)
  }

  // suppress unused selectedId — kept for state parity
  void selectedId

  return (
    <section className="py-8 px-4 border-t border-neon-green/10">
      <div className="max-w-4xl mx-auto">
        <h2
          className="font-display font-bold text-2xl tracking-widest text-degen-text uppercase text-center mb-5 cursor-pointer hover:text-neon-green transition-colors"
          onClick={() => setModalOpen(true)}
        >
          PREVIOUS RESULTS
        </h2>

        {/* Previous Results Modal */}
        <ReactModal
          isOpen={modalOpen}
          onRequestClose={() => setModalOpen(false)}
          contentLabel="Previous Results"
          style={{
            content: {
              top: '50%', left: '50%', right: 'auto', bottom: 'auto',
              transform: 'translate(-50%,-50%)',
              width: '90%', maxWidth: '1200px', height: '80vh',
              background: '#0A0A0A',
              border: '1px solid rgba(0,255,65,0.15)',
              borderRadius: '0',
              padding: '1.5rem',
            },
            overlay: { backgroundColor: 'rgba(3,3,3,0.92)', backdropFilter: 'blur(4px)', zIndex: 100 },
          }}
        >
          <div className="flex justify-between items-center mb-6">
            <h2 className="font-display font-bold text-2xl tracking-widest text-degen-text uppercase">Previous Results</h2>
            <button
              onClick={() => setModalOpen(false)}
              className="text-degen-muted hover:text-degen-text text-2xl leading-none transition-colors"
            >
              &times;
            </button>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 max-h-[60vh] overflow-y-auto pr-1">
            {winners.map((winner) => (
              <div
                key={winner.id}
                className={`bg-degen-panel border p-4 ${
                  !winner.isRevealed
                    ? 'border-neon-green/40 shadow-neon-green'
                    : 'border-neon-green/10'
                }`}
              >
                <div className="flex justify-between border-b border-degen-muted/20 pb-3 mb-3">
                  <div>
                    <h3 className="font-display font-bold text-degen-text">TOSS# {String(winner.id).padStart(5, '0')}</h3>
                    <p className="font-mono text-xs text-degen-muted mt-0.5">{winner.timestamp}</p>
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-2 mb-3">
                  <div className="border-r border-degen-muted/20 pr-2">
                    <p className="font-mono text-3xl font-bold text-degen-text">{winner.amount}</p>
                    <p className="font-display text-xs text-degen-muted uppercase tracking-wide mt-0.5">Pool Size</p>
                  </div>
                  <div className="pl-2">
                    <p className={`font-mono text-3xl font-bold ${
                      winner.isRevealed
                        ? winner.bet === winner.result ? 'neon-green-text' : 'neon-red-text'
                        : 'text-degen-text'
                    }`}>
                      {winner.amount}
                    </p>
                    <p className="font-display text-xs text-degen-muted uppercase tracking-wide mt-0.5">My Bet</p>
                  </div>
                </div>
                <div className="border-t border-degen-muted/20 pt-3">
                  {winner.isRevealed ? (
                    <div className="flex justify-between items-center">
                      <p className={`font-display font-bold text-3xl ${winner.result === winner.bet ? 'neon-green-text' : 'neon-red-text'}`}>
                        {winner.result}
                      </p>
                      {winner.winnings > 0 && (
                        <p className="font-mono text-2xl font-bold neon-green-text">+{winner.winnings}</p>
                      )}
                    </div>
                  ) : (
                    <button
                      className="w-full font-display font-bold text-sm tracking-widest bg-neon-green text-degen-black py-3 uppercase hover:shadow-neon-green transition-all flex justify-center items-center gap-2"
                      onClick={() => handleResultClick(winner.id)}
                    >
                      See My Results <span className="text-xl">🎲</span>
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        </ReactModal>

        {confetti && <Confetti width={width} height={height} />}
        {sadEmoji && (
          <div className="fixed inset-0 flex items-center justify-center z-50">
            <div className="absolute inset-0 bg-black bg-opacity-50 z-40" />
            <div className="relative z-50 text-9xl animate-bounce">{sadEmoji}</div>
          </div>
        )}
        {rolling && (
          <div className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-75 z-50">
            <span className="text-white text-9xl" style={{ animation: 'spin-coin 3s forwards' }}>🎲</span>
          </div>
        )}

        {/* Summary rows */}
        {winners.slice(0, 5).map((winner) => (
          <div key={winner.id} className="bg-degen-panel border border-neon-green/10 p-4 mb-3 grid grid-cols-12 items-center">
            <img
              src={winner.result === 'HEADS' ? '/coin-heads.png' : '/coin-tails.png'}
              alt="Coin"
              className="h-10 w-10 col-span-2"
            />
            <div className="col-span-8 flex flex-col">
              <p className="font-display font-bold text-degen-text text-sm">
                <span className={winner.result === 'HEADS' ? 'neon-green-text' : 'neon-red-text'}>{winner.result}</span>
                {' — '}
                <span className="font-mono text-xs text-degen-muted">{winner.timestamp}</span>
                {' '}
                <span className="font-mono text-xs text-degen-muted/60">{winner.hash}</span>
              </p>
              <button
                onClick={() => setModalOpen(true)}
                className="mt-1 self-start font-display text-xs tracking-widest text-neon-green hover:text-neon-green/70 uppercase transition-colors"
              >
                See more
              </button>
            </div>
            <div className="col-span-2 flex justify-end items-center gap-1">
              <img src="/flow.png" alt="Flow" className="h-6 w-6" />
              <span className="font-mono text-base font-bold text-degen-text">${winner.amount.toLocaleString()}</span>
            </div>
          </div>
        ))}

        <button
          className="font-display text-xs tracking-widest text-neon-green hover:text-neon-green/70 uppercase mx-auto my-4 p-2 block transition-colors"
          onClick={() => setModalOpen(true)}
        >
          CLICK HERE TO SEE MORE RESULTS
        </button>
      </div>
    </section>
  )
}

export default PreviousWinners

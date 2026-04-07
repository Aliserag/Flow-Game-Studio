import React from 'react'

const MOCK_LEADERS = [
  { id: 1, name: '0x43hj44930ffs', score: 1888.33 },
  { id: 2, name: '0x47dk32910ksd', score: 1750.00 },
  { id: 3, name: '0x94dj32197dd3', score: 1623.45 },
  { id: 4, name: '0x23ff44930lls', score: 1488.33 },
  { id: 5, name: '0x55gj44930ffr', score: 1340.78 },
]

const rankBorderClass = (index: number): string => {
  if (index === 0) return 'border-neon-amber/40'
  if (index === 1) return 'border-degen-muted/50'
  if (index === 2) return 'border-degen-muted/30'
  return 'border-neon-green/10'
}

const Leaderboard = () => (
  <section className="py-8 px-4 border-t border-neon-green/10">
    <div className="max-w-4xl mx-auto">
      <h2 className="font-display font-bold text-2xl tracking-widest text-degen-text uppercase text-center mb-6">
        LEADERBOARD
      </h2>
      {MOCK_LEADERS.map((leader, index) => (
        <div
          key={leader.id}
          className={`bg-degen-panel border p-4 mb-2 grid grid-cols-12 items-center ${rankBorderClass(index)}`}
        >
          <div className="col-span-2 flex items-center">
            <span className={`font-mono font-bold text-lg ${index === 0 ? 'neon-amber-text' : 'text-degen-muted'}`}>
              #{index + 1}
            </span>
          </div>
          <div className="col-span-7 flex items-center">
            <span className="font-mono text-degen-text text-sm truncate">{leader.name}</span>
          </div>
          <div className="col-span-3 flex justify-end">
            <span className="font-mono text-neon-green font-bold text-xl">
              {leader.score.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </span>
          </div>
        </div>
      ))}
    </div>
  </section>
)

export default Leaderboard

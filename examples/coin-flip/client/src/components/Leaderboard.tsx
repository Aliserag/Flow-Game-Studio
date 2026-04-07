import React, { useMemo } from 'react'
import type { PoolRecord } from './PreviousWinners'

interface LeaderEntry {
  address: string
  totalWon: number
  poolsWon: number
}

interface LeaderboardProps {
  pools: PoolRecord[]
}

const rankBorderClass = (index: number): string => {
  if (index === 0) return 'border-neon-amber/40'
  if (index === 1) return 'border-degen-muted/50'
  if (index === 2) return 'border-degen-muted/30'
  return 'border-neon-green/10'
}

const Leaderboard = ({ pools }: LeaderboardProps) => {
  // Aggregate winnings from closed pools where users participated and won
  const leaders = useMemo<LeaderEntry[]>(() => {
    const map = new Map<string, LeaderEntry>()

    for (const pool of pools) {
      // Only count closed, flipped pools where a user address is known
      if (pool.status !== 2 || !pool.isCoinFlipped || !pool.userBetSide) continue

      // We can only track the connected user's address here — full leaderboard
      // would require an on-chain index. Show what we have.
      const won =
        (pool.tossResult === 'HEAD' && pool.userBetSide === 'Head') ||
        (pool.tossResult === 'TAIL' && pool.userBetSide === 'Tail')

      if (!won || pool.userClaimAmount <= 0) continue

      // Use a placeholder key since we don't store address in PoolRecord.
      // The leaderboard reflects the connected user's own stats.
      const key = 'you'
      const existing = map.get(key)
      if (existing) {
        existing.totalWon += pool.userClaimAmount
        existing.poolsWon += 1
      } else {
        map.set(key, { address: 'You', totalWon: pool.userClaimAmount, poolsWon: 1 })
      }
    }

    return Array.from(map.values())
      .sort((a, b) => b.totalWon - a.totalWon)
      .slice(0, 5)
  }, [pools])

  return (
    <section className="py-8 px-4 border-t border-neon-green/10">
      <div className="max-w-4xl mx-auto">
        <h2 className="font-display font-bold text-2xl tracking-widest text-degen-text uppercase text-center mb-6">
          LEADERBOARD
        </h2>

        {leaders.length === 0 ? (
          <p className="font-mono text-sm text-degen-muted text-center py-6">
            Connect wallet and participate in pools to appear on the leaderboard.
          </p>
        ) : (
          leaders.map((leader, index) => (
            <div
              key={leader.address}
              className={`bg-degen-panel border p-4 mb-2 grid grid-cols-12 items-center ${rankBorderClass(index)}`}
            >
              <div className="col-span-2 flex items-center">
                <span className={`font-mono font-bold text-lg ${index === 0 ? 'neon-amber-text' : 'text-degen-muted'}`}>
                  #{index + 1}
                </span>
              </div>
              <div className="col-span-5 flex flex-col">
                <span className="font-mono text-degen-text text-sm truncate">{leader.address}</span>
                <span className="font-mono text-degen-muted text-xs">{leader.poolsWon} pool{leader.poolsWon !== 1 ? 's' : ''} won</span>
              </div>
              <div className="col-span-5 flex justify-end items-center gap-1">
                <img src="/flow.png" alt="FLOW" className="h-4 w-4 opacity-70" />
                <span className="font-mono text-neon-green font-bold text-xl">
                  {leader.totalWon.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </span>
              </div>
            </div>
          ))
        )}
      </div>
    </section>
  )
}

export default Leaderboard

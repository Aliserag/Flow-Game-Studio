import { useState, useEffect, useCallback } from 'react'
import * as fcl from '@onflow/fcl'
import Header from './Header'

// Phase 1: record block height on chain. Randomness for that block seals next block.
const ADMIN_COMMIT_TOSS = `
import CoinFlip from 0xCoinFlip

transaction(id: UInt64) {
    let adminRef: &CoinFlip.Admin
    prepare(signer: auth(BorrowValue) &Account) {
        self.adminRef = signer.storage.borrow<&CoinFlip.Admin>(from: /storage/CoinFlipGameManager)
            ?? panic("Signer is not the admin")
    }
    execute { self.adminRef.commitToss(id: id) }
}`

// Phase 2: fetch sealed randomness and resolve the pool.
// Must be called at least one block after commit.
const ADMIN_REVEAL_TOSS = `
import CoinFlip from 0xCoinFlip

transaction(id: UInt64) {
    let adminRef: &CoinFlip.Admin
    prepare(signer: auth(BorrowValue) &Account) {
        self.adminRef = signer.storage.borrow<&CoinFlip.Admin>(from: /storage/CoinFlipGameManager)
            ?? panic("Signer is not the admin")
    }
    execute { self.adminRef.tossCoin(id: id) }
}`

const GET_TOTAL_POOL = `
import CoinFlip from 0xCoinFlip
access(all) fun main(): UInt64 { return CoinFlip.totalPools }`

const GET_COMMITTED_HEIGHT = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): UInt64? {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).getCommittedHeight()
}`

interface User { loggedIn: boolean | null; addr?: string }
type TossPhase = 'idle' | 'committing' | 'committed' | 'revealing' | 'done' | 'error'

export default function Admin() {
  const [user, setUser] = useState<User>({ loggedIn: null })
  const [status, setStatus] = useState('')
  const [phase, setPhase] = useState<TossPhase>('idle')
  const [activePoolId, setActivePoolId] = useState<string | null>(null)

  useEffect(() => { fcl.currentUser.subscribe(setUser) }, [])

  // Only show to admin (testnet deployer account)
  const adminAddresses = ['0xeb24b78eb89a2076']
  if (!(user?.loggedIn && user.addr && adminAddresses.includes(user.addr))) {
    return (
      <div className="min-h-screen bg-degen-black degen-grid-bg scanlines">
        <div className="fixed inset-0 pointer-events-none z-10 bg-[radial-gradient(ellipse_at_top,transparent_50%,rgba(3,3,3,0.6)_100%)]" aria-hidden="true" />
        <div className="relative z-20">
          <Header />
          <div className="flex flex-col items-center justify-center min-h-[60vh] gap-6 px-4">
            <div className="font-mono text-xs tracking-[0.3em] text-degen-muted uppercase text-center border border-neon-red/20 bg-degen-panel px-6 py-4">
              <p className="neon-red-text mb-2">// RESTRICTED ACCESS</p>
              <p>Admin wallet required to enter</p>
            </div>
            {!user?.loggedIn && (
              <button
                onClick={() => fcl.authenticate()}
                className="font-display font-bold text-sm tracking-widest border border-neon-green/40 bg-degen-panel text-neon-green py-3 px-8 hover:border-neon-green hover:shadow-neon-green transition-all duration-200 uppercase"
              >
                CONNECT WALLET
              </button>
            )}
          </div>
        </div>
      </div>
    )
  }

  /** Phase 1: commit the toss (stores block height on-chain). */
  const commitToss = useCallback(async () => {
    try {
      setPhase('committing')
      setStatus('Fetching current pool...')
      const poolId = await fcl.query({ cadence: GET_TOTAL_POOL })
      setActivePoolId(String(poolId))
      setStatus(`Committing toss for pool #${poolId}...`)
      const txId = await fcl.mutate({
        cadence: ADMIN_COMMIT_TOSS,
        args: (arg: Function, t: unknown) => [arg(String(poolId), (t as any).UInt64)],
        payer: fcl.authz, proposer: fcl.authz, authorizations: [fcl.authz], limit: 100,
      })
      await fcl.tx(txId).onceSealed()
      setPhase('committed')
      setStatus(`Pool #${poolId} committed. Wait 1 block, then click REVEAL TOSS. ✓`)
    } catch (e: unknown) {
      setPhase('error')
      setStatus(`Error: ${e instanceof Error ? e.message : String(e)}`)
    }
  }, [])

  /** Phase 2: reveal uses the sealed block randomness to resolve the pool. */
  const revealToss = useCallback(async () => {
    if (!activePoolId) return
    try {
      setPhase('revealing')
      setStatus(`Revealing toss for pool #${activePoolId}...`)

      // Verify the pool has been committed before attempting reveal.
      const committedHeight = await fcl.query({
        cadence: GET_COMMITTED_HEIGHT,
        args: (arg: Function, t: unknown) => [arg(activePoolId, (t as any).UInt64)],
      })
      if (committedHeight == null) {
        throw new Error('Pool has no committed block height. Run COMMIT TOSS first.')
      }

      const txId = await fcl.mutate({
        cadence: ADMIN_REVEAL_TOSS,
        args: (arg: Function, t: unknown) => [arg(activePoolId, (t as any).UInt64)],
        payer: fcl.authz, proposer: fcl.authz, authorizations: [fcl.authz], limit: 100,
      })
      await fcl.tx(txId).onceSealed()
      setPhase('done')
      setStatus(`Pool #${activePoolId} resolved! New pool created automatically. ✓`)
      setActivePoolId(null)
    } catch (e: unknown) {
      setPhase('error')
      setStatus(`Error: ${e instanceof Error ? e.message : String(e)}`)
    }
  }, [activePoolId])

  const reset = () => { setPhase('idle'); setStatus(''); setActivePoolId(null) }

  const isCommitting = phase === 'committing'
  const isRevealing = phase === 'revealing'

  return (
    <div className="min-h-screen bg-degen-black degen-grid-bg scanlines">
      <div className="fixed inset-0 pointer-events-none z-10 bg-[radial-gradient(ellipse_at_top,transparent_50%,rgba(3,3,3,0.6)_100%)]" aria-hidden="true" />
      <div className="relative z-20">
        <Header />
        <div className="max-w-2xl mx-auto px-4 py-12">
          {/* Admin header */}
          <div className="border border-neon-amber/30 bg-degen-panel px-6 py-4 mb-8 flex items-center gap-3">
            <span className="neon-amber-text text-lg">⚡</span>
            <div>
              <h1 className="font-display font-bold text-xl tracking-widest neon-amber-text uppercase">Admin Control Panel</h1>
              <p className="font-mono text-xs text-degen-muted tracking-wide mt-0.5">
                Connected: <span className="text-neon-green">{user.addr}</span>
              </p>
            </div>
          </div>

          {/* Two-phase toss controls */}
          <div className="flex gap-3 mb-4">
            <button
              onClick={commitToss}
              disabled={isCommitting || isRevealing || phase === 'committed'}
              className="flex-1 font-display font-bold text-base tracking-widest bg-neon-amber text-degen-black py-4 px-8 hover:shadow-neon-amber hover:-translate-y-0.5 active:translate-y-0 transition-all duration-150 uppercase disabled:opacity-40 disabled:cursor-not-allowed disabled:transform-none"
            >
              {isCommitting ? '⏳ COMMITTING…' : '1. COMMIT TOSS'}
            </button>

            <button
              onClick={revealToss}
              disabled={isCommitting || isRevealing || phase !== 'committed'}
              className="flex-1 font-display font-bold text-base tracking-widest bg-neon-green text-degen-black py-4 px-8 hover:shadow-neon-green hover:-translate-y-0.5 active:translate-y-0 transition-all duration-150 uppercase disabled:opacity-40 disabled:cursor-not-allowed disabled:transform-none"
            >
              {isRevealing ? '⏳ REVEALING…' : '2. REVEAL TOSS'}
            </button>
          </div>

          {phase === 'error' && (
            <button onClick={reset} className="w-full font-mono text-xs text-neon-red border border-neon-red/40 py-2 mb-4 hover:bg-neon-red/10 transition-colors">
              ↩ RESET
            </button>
          )}

          {status && (
            <p className={`font-mono text-sm border-l-2 pl-4 py-2 bg-degen-panel mb-6 ${phase === 'error' ? 'text-neon-red border-neon-red/40' : 'text-neon-green border-neon-green/40'}`}>
              {status}
            </p>
          )}

          {/* Instructions */}
          <div className="border border-neon-green/10 bg-degen-panel p-5 mt-4">
            <h2 className="font-display font-bold text-xs tracking-widest text-degen-muted uppercase mb-3">// Two-Phase Toss (Secure VRF)</h2>
            <ol className="space-y-2">
              {[
                'Wait for the pool betting window to close',
                'Click COMMIT TOSS — records current block height on-chain',
                'Wait for the commit tx to seal (≥1 block)',
                'Click REVEAL TOSS — uses sealed block randomness (non-revertible)',
                'A new pool is created automatically after reveal',
                'Winners can claim their rewards on the main page',
              ].map((step, i) => (
                <li key={i} className="flex gap-3 font-mono text-xs text-degen-muted">
                  <span className="neon-green-text font-bold shrink-0">{String(i + 1).padStart(2, '0')}.</span>
                  <span>{step}</span>
                </li>
              ))}
            </ol>
            <p className="font-mono text-xs text-degen-muted/60 mt-3 border-t border-neon-green/10 pt-3">
              Two-phase design prevents validator revert attacks on the random outcome.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}

import { useState, useEffect } from 'react'
import * as fcl from '@onflow/fcl'
import Header from './Header'

const ADMIN_TOSS = `
import FungibleToken from 0xFungibleToken
import FlowToken from 0xFlowToken
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

interface User { loggedIn: boolean | null; addr?: string }

export default function Admin() {
  const [user, setUser] = useState<User>({ loggedIn: null })
  const [status, setStatus] = useState('')

  useEffect(() => { fcl.currentUser.subscribe(setUser) }, [])

  // Only show to admin (emulator account)
  const adminAddresses = ['0xf8d6e0586b0a20c7']
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

  const tossTheCoin = async () => {
    try {
      setStatus('Fetching current pool...')
      const poolId = await fcl.query({ cadence: GET_TOTAL_POOL })
      setStatus(`Tossing coin for pool #${poolId}...`)
      const txId = await fcl.mutate({
        cadence: ADMIN_TOSS,
        args: (arg: Function, t: any) => [arg(String(poolId), t.UInt64)],
        payer: fcl.authz, proposer: fcl.authz, authorizations: [fcl.authz], limit: 999,
      })
      await fcl.tx(txId).onceSealed()
      setStatus(`Coin tossed for pool #${poolId}! New pool created. ✓`)
    } catch (e: any) {
      setStatus(`Error: ${e.message}`)
    }
  }

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

          {/* Toss button */}
          <button
            onClick={tossTheCoin}
            className="w-full font-display font-bold text-base tracking-widest bg-neon-green text-degen-black py-4 px-8 hover:shadow-neon-green hover:-translate-y-0.5 active:translate-y-0 transition-all duration-150 uppercase mb-4"
          >
            ⚡ TOSS THE COIN
          </button>

          {status && (
            <p className="font-mono text-sm text-neon-green border-l-2 border-neon-green/40 pl-4 py-2 bg-degen-panel mb-6">
              {status}
            </p>
          )}

          {/* Instructions */}
          <div className="border border-neon-green/10 bg-degen-panel p-5 mt-4">
            <h2 className="font-display font-bold text-xs tracking-widest text-degen-muted uppercase mb-3">// Instructions</h2>
            <ol className="space-y-2">
              {[
                'Wait for the pool betting window to close (5 min on emulator)',
                'Click TOSS THE COIN to determine the winner via VRF',
                'A new pool is automatically created after each toss',
                'Winners can claim at the main page',
              ].map((step, i) => (
                <li key={i} className="flex gap-3 font-mono text-xs text-degen-muted">
                  <span className="neon-green-text font-bold shrink-0">{String(i + 1).padStart(2, '0')}.</span>
                  <span>{step}</span>
                </li>
              ))}
            </ol>
          </div>
        </div>
      </div>
    </div>
  )
}

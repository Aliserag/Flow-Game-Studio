import React, { useState, useEffect } from 'react'
import * as fcl from '@onflow/fcl'
import CoinTossSection from '../components/CoinTossSection'
import Leaderboard from '../components/Leaderboard'
import PreviousWinners, { type PoolRecord } from '../components/PreviousWinners'
import Footer from '../components/Footer'
import Header from '../components/Header'

function Home() {
  const [currentPoolId, setCurrentPoolId] = useState(1)
  const [userAddr, setUserAddr] = useState<string | null>(null)
  const [pools, setPools] = useState<PoolRecord[]>([])

  useEffect(() => {
    const unsub = fcl.currentUser.subscribe((u: any) => {
      setUserAddr(u?.addr ?? null)
    })
    return unsub
  }, [])

  return (
    <div className="min-h-screen bg-degen-black degen-grid-bg scanlines relative font-display">
      {/* Vignette overlay */}
      <div className="fixed inset-0 pointer-events-none z-10 bg-[radial-gradient(ellipse_at_top,transparent_50%,rgba(3,3,3,0.6)_100%)]" aria-hidden="true" />

      <div className="relative z-20">
        <Header />
        <main>
          <CoinTossSection onPoolIdChange={setCurrentPoolId} />
          <PreviousWinners
            currentPoolId={currentPoolId}
            userAddr={userAddr}
            onPoolsLoaded={setPools}
          />
          <Leaderboard pools={pools} />
        </main>
        <Footer />
      </div>
    </div>
  )
}

export default Home

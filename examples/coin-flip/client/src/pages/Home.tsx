import React from 'react'
import CoinTossSection from '../components/CoinTossSection'
import Leaderboard from '../components/Leaderboard'
import PreviousWinners from '../components/PreviousWinners'
import Footer from '../components/Footer'
import Header from '../components/Header'

function Home() {
  return (
    <div className="min-h-screen bg-degen-black degen-grid-bg scanlines relative font-display">
      {/* Vignette overlay */}
      <div className="fixed inset-0 pointer-events-none z-10 bg-[radial-gradient(ellipse_at_top,transparent_50%,rgba(3,3,3,0.6)_100%)]" aria-hidden="true" />

      <div className="relative z-20">
        <Header />
        <main>
          <CoinTossSection />
          <PreviousWinners />
          <Leaderboard />
        </main>
        <Footer />
      </div>
    </div>
  )
}

export default Home

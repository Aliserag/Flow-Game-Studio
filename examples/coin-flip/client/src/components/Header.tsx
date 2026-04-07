import { useState, useEffect } from 'react'
import * as fcl from '@onflow/fcl'

interface User {
  loggedIn: boolean | null
  addr?: string
}

const Header = () => {
  const [user, setUser] = useState<User>({ loggedIn: null })
  const [dropdownOpen, setDropdownOpen] = useState(false)

  useEffect(() => {
    fcl.currentUser.subscribe(setUser)
  }, [])

  const truncateAddress = (address?: string) => {
    if (!address) return 'No Address'
    return `${address.slice(0, 6)}...${address.slice(-4)}`
  }

  const WalletButton = () => (
    <div className="relative">
      <button
        className="font-mono text-sm border border-neon-green/40 bg-degen-panel text-degen-text py-2 px-4 flex items-center gap-2 hover:border-neon-green/80 hover:text-neon-green transition-all duration-200 min-w-[170px]"
        onClick={() => user.loggedIn ? setDropdownOpen(!dropdownOpen) : fcl.authenticate()}
      >
        <img src="/enter.png" alt="" className="h-4 w-4 opacity-70" />
        <span className="neon-green-text">{user.loggedIn ? truncateAddress(user.addr) : 'CONNECT WALLET'}</span>
      </button>
      {dropdownOpen && user.loggedIn && (
        <div className="absolute right-0 mt-1 w-48 bg-degen-panel border border-neon-green/20 z-50 shadow-neon-green">
          <button
            className="block w-full text-left px-4 py-3 text-sm font-mono text-degen-muted hover:text-neon-red hover:bg-neon-red/5 transition-colors"
            onClick={() => { fcl.unauthenticate(); setDropdownOpen(false) }}
          >
            DISCONNECT
          </button>
        </div>
      )}
    </div>
  )

  return (
    <header className="bg-degen-dark border-b border-neon-green/10 px-4 sm:px-8 py-4 flex items-center justify-between gap-4">
      {/* Left: Shield + branding */}
      <div className="flex items-center gap-3 min-w-[160px]">
        <div className="relative">
          <img src="/shield.png" alt="Shield" className="h-8 w-8 drop-shadow-[0_0_8px_rgba(0,255,65,0.4)]" />
        </div>
        <div>
          <p className="font-display font-bold text-xs tracking-widest neon-green-text">PROVABLY FAIR</p>
          <p className="font-mono text-[10px] text-degen-muted tracking-wide">100% ON-CHAIN</p>
        </div>
      </div>

      {/* Center: YOLO logo */}
      <div className="flex-1 flex justify-center">
        <img src="/yolo-today.png" alt="YOLO Today" className="h-24 sm:h-36 object-contain" />
      </div>

      {/* Right: Wallet */}
      <div className="min-w-[160px] flex justify-end">
        <WalletButton />
      </div>
    </header>
  )
}

export default Header

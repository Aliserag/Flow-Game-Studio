import React, { useState, useEffect, useRef } from 'react'
import Countdown from 'react-countdown'
import * as fcl from '@onflow/fcl'
import ReactModal from 'react-modal'

// ============================================================
// TRANSACTIONS (unchanged)
// ============================================================
const BET_ON_HEAD = `
import FungibleToken from 0xFungibleToken
import FlowToken from 0xFlowToken
import CoinFlip from 0xCoinFlip

transaction(id: UInt64, amount: UFix64) {
    let payment: @FlowToken.Vault
    let buyer: Address
    prepare(signer: auth(BorrowValue) &Account) {
        let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FlowToken vault")
        self.payment <- flowVault.withdraw(amount: amount) as! @FlowToken.Vault
        self.buyer = signer.address
    }
    execute {
        let poolRef = CoinFlip.borrowPool(id: id)
        poolRef.betOnHead(_addr: self.buyer, poolId: id, amount: <- self.payment)
    }
}`

const BET_ON_TAIL = `
import FungibleToken from 0xFungibleToken
import FlowToken from 0xFlowToken
import CoinFlip from 0xCoinFlip

transaction(id: UInt64, amount: UFix64) {
    let payment: @FlowToken.Vault
    let buyer: Address
    prepare(signer: auth(BorrowValue) &Account) {
        let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FlowToken vault")
        self.payment <- flowVault.withdraw(amount: amount) as! @FlowToken.Vault
        self.buyer = signer.address
    }
    execute {
        let poolRef = CoinFlip.borrowPool(id: id)
        poolRef.betOnTail(_addr: self.buyer, poolId: id, amount: <- self.payment)
    }
}`

const CLAIM_REWARD = `
import FungibleToken from 0xFungibleToken
import FlowToken from 0xFlowToken
import CoinFlip from 0xCoinFlip

transaction(id: UInt64) {
    let buyer: Address
    prepare(signer: auth(BorrowValue) &Account) {
        self.buyer = signer.address
    }
    execute {
        CoinFlip.claimReward(poolId: id, userAddress: self.buyer)
    }
}`

// ============================================================
// SCRIPTS — existing
// ============================================================
const GET_TOTAL_POOL = `
import CoinFlip from 0xCoinFlip
access(all) fun main(): UInt64 { return CoinFlip.totalPools }`

const GET_HEAD_VAULT_BALANCE = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): UFix64 {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).getHeadBalance()
}`

const GET_TAIL_VAULT_BALANCE = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): UFix64 {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).getTailBalance()
}`

const GET_POOL_TOTAL_BALANCE = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): UFix64 {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).getPoolTotalBalance()
}`

const GET_TIME_LEFT = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): Int {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    let diff = Int(CoinFlip.borrowPool(id: id).endTime) - Int(getCurrentBlock().timestamp)
    return diff > 0 ? diff : 0
}`

// ============================================================
// SCRIPTS — new
// ============================================================

// Pool status: returns UInt8 raw value (0=OPEN, 1=CALCULATING, 2=CLOSE)
// Uses getStatus() getter — status field is access(contract)
const GET_POOL_STATUS = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): UInt8 {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).getStatus().rawValue
}`

// Toss result: returns "" | "HEAD" | "TAIL"
// Uses getTossResult() getter — tossResult field is access(contract)
const GET_TOSS_RESULT = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): String {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).getTossResult()
}`

// Uses isCoinFlipped() getter — coinFlipped field is access(contract)
const IS_COIN_FLIPPED = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): Bool {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).isCoinFlipped()
}`

// Returns bet_amount if user has a head bet, nil otherwise
// Uses hasHeadBet() getter — headInfo dict is access(contract)
const GET_USER_BET_HEAD = `
import CoinFlip from 0xCoinFlip
access(all) fun main(poolId: UInt64, user: Address): UFix64? {
    pre { CoinFlip.totalPools >= poolId && poolId != 0: "Pool does not exist" }
    let pool = CoinFlip.borrowPool(id: poolId)
    if pool.hasHeadBet(addr: user) {
        return pool.getHeadBetUserInfo(addr: user).bet_amount
    }
    return nil
}`

// Returns bet_amount if user has a tail bet, nil otherwise
// Uses hasTailBet() getter — tailInfo dict is access(contract)
const GET_USER_BET_TAIL = `
import CoinFlip from 0xCoinFlip
access(all) fun main(poolId: UInt64, user: Address): UFix64? {
    pre { CoinFlip.totalPools >= poolId && poolId != 0: "Pool does not exist" }
    let pool = CoinFlip.borrowPool(id: poolId)
    if pool.hasTailBet(addr: user) {
        return pool.getTailBetUserInfo(_addr: user).bet_amount
    }
    return nil
}`

ReactModal.setAppElement('#root')

interface CoinTossSectionProps {
  onPoolIdChange?: (id: number) => void
}

const CoinTossSection = ({ onPoolIdChange }: CoinTossSectionProps) => {
  // Existing state
  const [coinSide, setCoinSide] = useState('')
  const [isFlipping, setIsFlipping] = useState(false)
  const [showModal, setShowModal] = useState(false)
  const [betAmount, setBetAmount] = useState('')
  const [selectedCoin, setSelectedCoin] = useState<'Head' | 'Tail' | null>(null)
  const [currentPoolId, setCurrentPoolId] = useState<number>(1)
  const [headBalance, setHeadBalance] = useState(0.0)
  const [tailBalance, setTailBalance] = useState(0.0)
  const [poolTotalBalance, setPoolTotalBalance] = useState(0.0)
  const [timeRemaining, setTimeRemaining] = useState<number | null>(null)
  const [status, setStatus] = useState('')

  // New state
  const [poolStatus, setPoolStatus] = useState<number>(0) // 0=OPEN, 1=CALCULATING, 2=CLOSE
  const [tossResult, setTossResult] = useState<string>('') // "" | "HEAD" | "TAIL"
  const [userBetSide, setUserBetSide] = useState<'Head' | 'Tail' | null>(null)
  const [userBetAmount, setUserBetAmount] = useState<number>(0)
  const [isPollingFlip, setIsPollingFlip] = useState(false)
  const [rewardClaimed, setRewardClaimed] = useState(false)

  const pollingIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  // Notify parent when pool ID changes
  useEffect(() => {
    onPoolIdChange?.(currentPoolId)
  }, [currentPoolId, onPoolIdChange])

  useEffect(() => {
    getTotalPool()
  }, [])

  useEffect(() => {
    if (currentPoolId < 1) return
    getHeadVaultBalance(currentPoolId)
    getTailVaultBalance(currentPoolId)
    getPoolTotalBalance(currentPoolId)
    fetchPoolStatus(currentPoolId)
    fetchTossResult(currentPoolId)
    // Reset per-pool user bet state when pool changes
    setUserBetSide(null)
    setUserBetAmount(0)
    setRewardClaimed(false)
  }, [currentPoolId])

  useEffect(() => {
    const id = setInterval(() => getTimeLeft(currentPoolId), 3000)
    return () => clearInterval(id)
  }, [currentPoolId])

  // Start/stop polling for coin flip when countdown expires
  useEffect(() => {
    const countdownDone = timeRemaining !== null && timeRemaining <= 0
    // During CALCULATING phase, tossResult holds the committed block height as a decimal
    // string (e.g. "12345678"). The coin is not yet flipped until tossResult is "HEAD"/"TAIL".
    const coinLanded = tossResult === 'HEAD' || tossResult === 'TAIL'
    const notYetFlipped = !coinLanded

    if (countdownDone && notYetFlipped && !isPollingFlip) {
      setIsPollingFlip(true)
      pollingIntervalRef.current = setInterval(async () => {
        try {
          const flipped = await fcl.query({
            cadence: IS_COIN_FLIPPED,
            args: (arg: Function, t: any) => [arg(String(currentPoolId), t.UInt64)],
          })
          if (flipped === true) {
            // Fetch the actual result
            await fetchTossResult(currentPoolId)
            await fetchPoolStatus(currentPoolId)
            await getTotalPool() // Pool ID advances after toss
            if (pollingIntervalRef.current) {
              clearInterval(pollingIntervalRef.current)
              pollingIntervalRef.current = null
            }
            setIsPollingFlip(false)
          }
        } catch (e) {
          console.error('Polling isCoinFlipped:', e)
        }
      }, 2000)
    }

    if (coinLanded && pollingIntervalRef.current) {
      clearInterval(pollingIntervalRef.current)
      pollingIntervalRef.current = null
      setIsPollingFlip(false)
    }

    return () => {
      if (pollingIntervalRef.current) {
        clearInterval(pollingIntervalRef.current)
        pollingIntervalRef.current = null
      }
    }
  }, [timeRemaining, tossResult, currentPoolId, isPollingFlip])

  const headBalFormatted = parseFloat(headBalance.toString()).toFixed(1)
  const tailBalFormatted = parseFloat(tailBalance.toString()).toFixed(1)

  const handleBet = () => {
    const bet = parseFloat(betAmount).toFixed(1)
    if (selectedCoin === 'Head') betOnHead(currentPoolId, bet)
    else if (selectedCoin === 'Tail') betOnTail(currentPoolId, bet)
    setShowModal(false)
  }

  const flipCoin = () => {
    setIsFlipping(true)
    setTimeout(() => {
      const result = Math.random() < 0.5 ? 'heads' : 'tails'
      setCoinSide(result)
      setIsFlipping(false)
    }, 3000)
  }

  const renderer = ({ hours, minutes, seconds, completed }: { hours: number; minutes: number; seconds: number; completed: boolean }) => {
    if (completed) {
      if (tossResult === 'HEAD' || tossResult === 'TAIL') {
        return <div className="font-mono text-neon-green text-sm tracking-widest">Coin has landed!</div>
      }
      return (
        <div className="flex flex-col items-center gap-1">
          <div className="font-mono text-neon-amber text-sm tracking-widest">Time&apos;s up! Waiting for toss...</div>
          {isPollingFlip && (
            <div className="font-mono text-degen-muted text-xs animate-pulse">Checking blockchain...</div>
          )}
        </div>
      )
    }
    return (
      <div className="flex items-end gap-2">
        <div>
          <div className="count-digit text-3xl sm:text-4xl">{String(hours).padStart(2, '0')}</div>
          <div className="count-label">Hours</div>
        </div>
        <div className="count-digit text-3xl sm:text-4xl mb-5">:</div>
        <div>
          <div className="count-digit text-3xl sm:text-4xl">{String(minutes).padStart(2, '0')}</div>
          <div className="count-label">Mins</div>
        </div>
        <div className="count-digit text-3xl sm:text-4xl mb-5">:</div>
        <div>
          <div className="count-digit text-3xl sm:text-4xl">{String(seconds).padStart(2, '0')}</div>
          <div className="count-label">Secs</div>
        </div>
      </div>
    )
  }

  // Determine if user won
  const userWon =
    (tossResult === 'HEAD' && userBetSide === 'Head') ||
    (tossResult === 'TAIL' && userBetSide === 'Tail')

  // ============================================================
  // FCL Transactions
  // ============================================================
  const betOnHead = async (id: number, amount: string) => {
    try {
      setStatus('Submitting HEAD bet...')
      const txId = await fcl.mutate({
        cadence: BET_ON_HEAD,
        args: (arg: Function, t: any) => [arg(String(id), t.UInt64), arg(amount, t.UFix64)],
        payer: fcl.authz, proposer: fcl.authz, authorizations: [fcl.authz], limit: 999,
      })
      await fcl.tx(txId).onceSealed()
      setStatus('Bet placed on HEADS! ✓')
      setUserBetSide('Head')
      setUserBetAmount(parseFloat(amount))
      getHeadVaultBalance(id)
      getPoolTotalBalance(id)
    } catch (e: any) {
      setStatus(`Error: ${e.message}`)
    }
  }

  const betOnTail = async (id: number, amount: string) => {
    try {
      setStatus('Submitting TAIL bet...')
      const txId = await fcl.mutate({
        cadence: BET_ON_TAIL,
        args: (arg: Function, t: any) => [arg(String(id), t.UInt64), arg(amount, t.UFix64)],
        payer: fcl.authz, proposer: fcl.authz, authorizations: [fcl.authz], limit: 999,
      })
      await fcl.tx(txId).onceSealed()
      setStatus('Bet placed on TAILS! ✓')
      setUserBetSide('Tail')
      setUserBetAmount(parseFloat(amount))
      getTailVaultBalance(id)
      getPoolTotalBalance(id)
    } catch (e: any) {
      setStatus(`Error: ${e.message}`)
    }
  }

  const claimReward = async (id: number) => {
    try {
      setStatus('Claiming reward...')
      const txId = await fcl.mutate({
        cadence: CLAIM_REWARD,
        args: (arg: Function, t: any) => [arg(String(id), t.UInt64)],
        payer: fcl.authz, proposer: fcl.authz, authorizations: [fcl.authz], limit: 999,
      })
      await fcl.tx(txId).onceSealed()
      setStatus('Reward claimed! ✓')
      setRewardClaimed(true)
    } catch (e: any) {
      setStatus(`Error: ${e.message}`)
    }
  }

  // ============================================================
  // FCL Scripts — existing
  // ============================================================
  const getTotalPool = async () => {
    try {
      const res = await fcl.query({ cadence: GET_TOTAL_POOL })
      setCurrentPoolId(Number(res))
    } catch (e) { console.error('getTotalPool:', e) }
  }

  const getHeadVaultBalance = async (id: number) => {
    try {
      const res = await fcl.query({
        cadence: GET_HEAD_VAULT_BALANCE,
        args: (arg: Function, t: any) => [arg(String(id), t.UInt64)],
      })
      setHeadBalance(parseFloat(res))
    } catch (e) { console.error('getHeadVaultBalance:', e) }
  }

  const getTailVaultBalance = async (id: number) => {
    try {
      const res = await fcl.query({
        cadence: GET_TAIL_VAULT_BALANCE,
        args: (arg: Function, t: any) => [arg(String(id), t.UInt64)],
      })
      setTailBalance(parseFloat(res))
    } catch (e) { console.error('getTailVaultBalance:', e) }
  }

  const getPoolTotalBalance = async (id: number) => {
    try {
      const res = await fcl.query({
        cadence: GET_POOL_TOTAL_BALANCE,
        args: (arg: Function, t: any) => [arg(String(id), t.UInt64)],
      })
      setPoolTotalBalance(parseFloat(res))
    } catch (e) { console.error('getPoolTotalBalance:', e) }
  }

  const getTimeLeft = async (id: number) => {
    try {
      const res = await fcl.query({
        cadence: GET_TIME_LEFT,
        args: (arg: Function, t: any) => [arg(String(id), t.UInt64)],
      })
      setTimeRemaining(Number(res))
    } catch (e) { console.error('getTimeLeft:', e) }
  }

  // ============================================================
  // FCL Scripts — new
  // ============================================================
  const fetchPoolStatus = async (id: number) => {
    try {
      const res = await fcl.query({
        cadence: GET_POOL_STATUS,
        args: (arg: Function, t: any) => [arg(String(id), t.UInt64)],
      })
      setPoolStatus(Number(res))
    } catch (e) { console.error('getPoolStatus:', e) }
  }

  const fetchTossResult = async (id: number) => {
    try {
      const res = await fcl.query({
        cadence: GET_TOSS_RESULT,
        args: (arg: Function, t: any) => [arg(String(id), t.UInt64)],
      })
      setTossResult(typeof res === 'string' ? res : '')
    } catch (e) { console.error('getTossResult:', e) }
  }

  const headPct = poolTotalBalance > 0 ? ((headBalance / poolTotalBalance) * 100).toFixed(1) : '0.0'
  const tailPct = poolTotalBalance > 0 ? ((tailBalance / poolTotalBalance) * 100).toFixed(1) : '0.0'

  // Result display helpers
  const resultLabel = tossResult === 'HEAD' ? 'HEADS WINS!' : tossResult === 'TAIL' ? 'TAILS WINS!' : null
  const resultColor = tossResult === 'HEAD' ? 'neon-green-text' : tossResult === 'TAIL' ? 'neon-red-text' : ''

  const poolIsOpen = poolStatus === 0
  const poolStatusLabel = poolStatus === 1 ? 'COIN FLIPPING...' : poolStatus === 2 ? 'POOL CLOSED' : null

  return (
    <section className="py-8 px-4">
      {/* HEADS / TAILS battle strip */}
      <div className="max-w-5xl mx-auto">
        <div className="grid grid-cols-3 gap-0 border border-neon-green/10">

          {/* HEADS side */}
          <div className="heads-panel p-6 sm:p-10 flex flex-col items-center justify-center gap-3">
            <p className="font-display font-bold text-xs tracking-[0.3em] text-neon-green/50 uppercase">Side A</p>
            <h2 className="font-display font-bold text-4xl sm:text-5xl neon-green-text animate-flicker">HEADS</h2>
            <div className="flex items-center gap-2 mt-1">
              <img src="/flow.png" alt="FLOW" className="h-5 w-5" />
              <span className="font-mono text-3xl sm:text-4xl font-medium text-degen-text">{headBalFormatted}</span>
            </div>
            <div className="font-mono text-sm border-t border-neon-green/20 pt-2 mt-1 w-full text-center">
              <span className="neon-green-text font-bold text-lg">{headPct}%</span>
              <span className="text-degen-muted ml-2 text-xs">OF POOL</span>
            </div>
          </div>

          {/* Center: coin + CTA */}
          <div className="bg-degen-panel border-x border-neon-green/10 flex flex-col items-center justify-center gap-4 p-6 sm:p-8">
            <div className="relative">
              <img
                src={coinSide === 'heads' ? '/coin-heads.png' : '/coin-tails.png'}
                onClick={flipCoin}
                alt="Coin — click to flip"
                title="Click to animate"
                className={`h-32 w-32 sm:h-44 sm:w-44 coin-image cursor-pointer ${isFlipping ? 'coin-flip-animation' : ''}`}
              />
            </div>

            {/* Result banner */}
            {resultLabel && (
              <div className={`font-display font-bold text-2xl tracking-widest text-center ${resultColor} border border-current px-4 py-2`}>
                🎯 {resultLabel}
              </div>
            )}

            {/* Pool closed / flipping indicator */}
            {!resultLabel && !poolIsOpen && poolStatusLabel && (
              <div className="font-display font-bold text-sm tracking-widest text-neon-amber text-center animate-pulse uppercase">
                {poolStatusLabel}
              </div>
            )}

            {/* Bet button — only when pool is OPEN */}
            {poolIsOpen && (
              <button
                onClick={() => setShowModal(true)}
                className="w-full font-display font-bold text-sm tracking-widest bg-neon-green text-degen-black py-3 px-6 hover:shadow-neon-green hover:-translate-y-0.5 active:translate-y-0 transition-all duration-150 uppercase"
              >
                BUY A TICKET
              </button>
            )}

            {/* Claim button — when user won and hasn't claimed yet */}
            {userWon && !rewardClaimed && poolStatus === 2 && (
              <button
                onClick={() => claimReward(currentPoolId)}
                className="w-full font-display font-bold text-sm tracking-widest bg-neon-amber text-degen-black py-3 px-6 hover:shadow-neon-amber hover:-translate-y-0.5 active:translate-y-0 transition-all duration-150 uppercase"
              >
                CLAIM REWARD
              </button>
            )}

            {/* Claimed badge */}
            {userWon && rewardClaimed && (
              <div className="font-mono text-xs text-neon-green text-center">Reward claimed ✓</div>
            )}

            {/* User bet info */}
            {userBetSide && (
              <p className="font-mono text-xs text-degen-muted text-center">
                Your bet: {userBetAmount.toFixed(1)} FLOW on {userBetSide === 'Head' ? 'HEADS' : 'TAILS'}
              </p>
            )}

            {status && (
              <p className="font-mono text-xs text-degen-muted text-center max-w-[200px] leading-relaxed">{status}</p>
            )}
          </div>

          {/* TAILS side */}
          <div className="tails-panel p-6 sm:p-10 flex flex-col items-center justify-center gap-3">
            <p className="font-display font-bold text-xs tracking-[0.3em] text-neon-red/50 uppercase">Side B</p>
            <h2 className="font-display font-bold text-4xl sm:text-5xl neon-red-text">TAILS</h2>
            <div className="flex items-center gap-2 mt-1">
              <img src="/flow.png" alt="FLOW" className="h-5 w-5" />
              <span className="font-mono text-3xl sm:text-4xl font-medium text-degen-text">{tailBalFormatted}</span>
            </div>
            <div className="font-mono text-sm border-t border-neon-red/20 pt-2 mt-1 w-full text-center">
              <span className="neon-red-text font-bold text-lg">{tailPct}%</span>
              <span className="text-degen-muted ml-2 text-xs">OF POOL</span>
            </div>
          </div>
        </div>

        {/* Countdown */}
        <div className="border border-neon-green/10 border-t-0 bg-degen-panel py-6 flex flex-col items-center gap-3">
          <p className="font-display text-xs tracking-[0.4em] text-degen-muted uppercase">Next Coin Toss</p>
          <div>
            {timeRemaining !== null ? (
              <Countdown date={Date.now() + timeRemaining * 1000} renderer={renderer} />
            ) : (
              <div className="font-mono text-degen-muted text-lg">Loading...</div>
            )}
          </div>
        </div>
      </div>

      {/* Bet Modal */}
      <ReactModal
        isOpen={showModal}
        onRequestClose={() => setShowModal(false)}
        style={{
          content: {
            top: '50%', left: '50%', right: 'auto', bottom: 'auto',
            marginRight: '-50%', transform: 'translate(-50%, -50%)',
            background: '#111118',
            border: '1px solid rgba(0,255,65,0.25)',
            outline: 'none',
            padding: '2rem',
            width: '90%',
            maxWidth: '480px',
            borderRadius: '0',
            overflow: 'visible',
          },
          overlay: { backgroundColor: 'rgba(3,3,3,0.9)', backdropFilter: 'blur(4px)', zIndex: 100 },
        }}
        contentLabel="Place Bet"
      >
        <div className="flex flex-col gap-4">
          {/* Header */}
          <div className="flex justify-between items-center">
            <h2 className="font-display font-bold text-xl tracking-widest text-degen-text uppercase">Pick a Side</h2>
            <button onClick={() => setShowModal(false)} className="text-degen-muted hover:text-degen-text text-2xl leading-none transition-colors">&times;</button>
          </div>

          {/* Coin picker */}
          <div className="grid grid-cols-2 gap-3">
            <button
              onClick={() => setSelectedCoin('Head')}
              className={`flex flex-col items-center gap-2 p-4 border transition-all duration-150 ${
                selectedCoin === 'Head'
                  ? 'border-neon-green bg-neon-green/5 shadow-neon-green'
                  : 'border-degen-muted/30 hover:border-neon-green/40 bg-degen-dark'
              }`}
            >
              <img src="/coin-heads.png" alt="Heads" className={`w-20 h-20 coin-image ${selectedCoin === 'Head' ? 'drop-shadow-[0_0_12px_rgba(0,255,65,0.5)]' : ''}`} />
              <span className={`font-display font-bold text-sm tracking-widest ${selectedCoin === 'Head' ? 'neon-green-text' : 'text-degen-muted'}`}>HEADS</span>
            </button>
            <button
              onClick={() => setSelectedCoin('Tail')}
              className={`flex flex-col items-center gap-2 p-4 border transition-all duration-150 ${
                selectedCoin === 'Tail'
                  ? 'border-neon-red bg-neon-red/5 shadow-neon-red'
                  : 'border-degen-muted/30 hover:border-neon-red/40 bg-degen-dark'
              }`}
            >
              <img src="/coin-tails.png" alt="Tails" className={`w-20 h-20 coin-image ${selectedCoin === 'Tail' ? 'drop-shadow-[0_0_12px_rgba(255,43,78,0.5)]' : ''}`} />
              <span className={`font-display font-bold text-sm tracking-widest ${selectedCoin === 'Tail' ? 'neon-red-text' : 'text-degen-muted'}`}>TAILS</span>
            </button>
          </div>

          {/* Amount input */}
          <div className="flex items-center gap-2 bg-degen-dark border border-neon-green/20 focus-within:border-neon-green/60 transition-colors">
            <input
              type="number"
              className="flex-1 bg-transparent px-4 py-3 font-mono text-degen-text focus:outline-none placeholder-degen-muted text-lg"
              value={betAmount}
              onChange={(e) => setBetAmount(e.target.value)}
              min="1"
              placeholder="Amount in FLOW"
            />
            <img src="/flow.png" alt="FLOW" className="w-5 h-5 mr-3 opacity-60" />
          </div>

          {/* Submit */}
          <button
            onClick={handleBet}
            disabled={!selectedCoin || !betAmount}
            className="w-full font-display font-bold tracking-widest text-sm uppercase py-4 bg-neon-green text-degen-black hover:shadow-neon-green hover:-translate-y-0.5 active:translate-y-0 transition-all duration-150 disabled:opacity-30 disabled:cursor-not-allowed disabled:transform-none"
          >
            CALL IT FRIENDO
          </button>

          {/* Pepe decorations */}
          <div className="flex justify-between items-end -mx-8 -mb-8">
            <img src="/pepe1.png" alt="" className="w-20 h-20 opacity-80" aria-hidden="true" />
            <img src="/pepe2.png" alt="" className="w-20 h-20 opacity-80" aria-hidden="true" />
          </div>
        </div>
      </ReactModal>

      {/* How It Works */}
      <div className="max-w-5xl mx-auto mt-8">
        <div className="border-t border-neon-green/10 py-3 text-center font-display text-xs tracking-[0.4em] text-degen-muted uppercase">
          HOW IT WORKS — Provably fair · VRF randomness · Flow blockchain
        </div>
      </div>
    </section>
  )
}

export default CoinTossSection

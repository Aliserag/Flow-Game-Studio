import React, { useState, useEffect, useCallback } from 'react'
import * as fcl from '@onflow/fcl'

// ============================================================
// CADENCE SCRIPTS
// ============================================================

// Pool status raw value: 0=OPEN, 1=CALCULATING, 2=CLOSE
const GET_POOL_STATUS = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): UInt8 {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).status.rawValue
}`

// Toss result: "" | "HEAD" | "TAIL"
const GET_TOSS_RESULT = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): String {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).tossResult
}`

const IS_COIN_FLIPPED = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): Bool {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).coinFlipped
}`

const GET_HEAD_BALANCE = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): UFix64 {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).getHeadBalance()
}`

const GET_TAIL_BALANCE = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): UFix64 {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).getTailBalance()
}`

const GET_END_TIME = `
import CoinFlip from 0xCoinFlip
access(all) fun main(id: UInt64): UFix64 {
    pre { CoinFlip.totalPools >= id && id != 0: "Pool does not exist" }
    return CoinFlip.borrowPool(id: id).endTime
}`

// Returns bet_amount if user has a head bet on this pool, nil otherwise
const GET_USER_BET_HEAD = `
import CoinFlip from 0xCoinFlip
access(all) fun main(poolId: UInt64, user: Address): UFix64? {
    pre { CoinFlip.totalPools >= poolId && poolId != 0: "Pool does not exist" }
    let pool = CoinFlip.borrowPool(id: poolId)
    if pool.headInfo[user] != nil {
        return pool.getHeadBetUserInfo(addr: user).bet_amount
    }
    return nil
}`

// Returns bet_amount if user has a tail bet on this pool, nil otherwise
const GET_USER_BET_TAIL = `
import CoinFlip from 0xCoinFlip
access(all) fun main(poolId: UInt64, user: Address): UFix64? {
    pre { CoinFlip.totalPools >= poolId && poolId != 0: "Pool does not exist" }
    let pool = CoinFlip.borrowPool(id: poolId)
    if pool.tailInfo[user] != nil {
        return pool.getTailBetUserInfo(_addr: user).bet_amount
    }
    return nil
}`

// Returns claim_amount for a head bettor (0.0 if not set yet)
const GET_USER_HEAD_CLAIM = `
import CoinFlip from 0xCoinFlip
access(all) fun main(poolId: UInt64, user: Address): UFix64? {
    pre { CoinFlip.totalPools >= poolId && poolId != 0: "Pool does not exist" }
    let pool = CoinFlip.borrowPool(id: poolId)
    if pool.headInfo[user] != nil {
        return pool.getHeadBetUserInfo(addr: user).claim_amount
    }
    return nil
}`

// Returns claim_amount for a tail bettor (0.0 if not set yet)
const GET_USER_TAIL_CLAIM = `
import CoinFlip from 0xCoinFlip
access(all) fun main(poolId: UInt64, user: Address): UFix64? {
    pre { CoinFlip.totalPools >= poolId && poolId != 0: "Pool does not exist" }
    let pool = CoinFlip.borrowPool(id: poolId)
    if pool.tailInfo[user] != nil {
        return pool.getTailBetUserInfo(_addr: user).claim_amount
    }
    return nil
}`

// Returns rewardClaimed flag for head bettor
const GET_USER_HEAD_CLAIMED = `
import CoinFlip from 0xCoinFlip
access(all) fun main(poolId: UInt64, user: Address): Bool? {
    pre { CoinFlip.totalPools >= poolId && poolId != 0: "Pool does not exist" }
    let pool = CoinFlip.borrowPool(id: poolId)
    if pool.headInfo[user] != nil {
        return pool.getHeadBetUserInfo(addr: user).rewardClaimed
    }
    return nil
}`

// Returns rewardClaimed flag for tail bettor
const GET_USER_TAIL_CLAIMED = `
import CoinFlip from 0xCoinFlip
access(all) fun main(poolId: UInt64, user: Address): Bool? {
    pre { CoinFlip.totalPools >= poolId && poolId != 0: "Pool does not exist" }
    let pool = CoinFlip.borrowPool(id: poolId)
    if pool.tailInfo[user] != nil {
        return pool.getTailBetUserInfo(_addr: user).rewardClaimed
    }
    return nil
}`

// ============================================================
// CLAIM REWARD TRANSACTION
// ============================================================
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
// TYPES
// ============================================================
export interface PoolRecord {
  poolId: number
  status: number         // 0=OPEN, 1=CALCULATING, 2=CLOSE
  tossResult: string     // "" | "HEAD" | "TAIL"
  headBalance: number
  tailBalance: number
  totalBalance: number
  endTime: number
  isCoinFlipped: boolean
  userBetSide: 'Head' | 'Tail' | null
  userBetAmount: number
  userClaimAmount: number
  userRewardClaimed: boolean
}

interface PreviousWinnersProps {
  currentPoolId: number
  userAddr: string | null
  onPoolsLoaded?: (pools: PoolRecord[]) => void
}

// ============================================================
// HELPERS
// ============================================================
function formatTimestamp(endTimeSec: number): string {
  if (!endTimeSec) return '—'
  const d = new Date(endTimeSec * 1000)
  return d.toLocaleString('en-US', {
    month: 'short', day: 'numeric', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

// ============================================================
// COMPONENT
// ============================================================
const PreviousWinners = ({ currentPoolId, userAddr, onPoolsLoaded }: PreviousWinnersProps) => {
  const [pools, setPools] = useState<PoolRecord[]>([])
  const [loading, setLoading] = useState(false)
  const [myPoolsOnly, setMyPoolsOnly] = useState(false)
  const [claimingPoolId, setClaimingPoolId] = useState<number | null>(null)
  const [expanded, setExpanded] = useState(false)

  const fetchPoolData = useCallback(async () => {
    if (currentPoolId < 1) return
    setLoading(true)

    // Fetch all completed pools (1 through currentPoolId - 1)
    // Also fetch the current pool if it's already closed/flipped
    const poolIds: number[] = []
    for (let i = currentPoolId; i >= 1; i--) {
      poolIds.push(i)
    }

    const results: PoolRecord[] = []

    await Promise.all(
      poolIds.map(async (id) => {
        try {
          const [statusRaw, tossResult, isCoinFlipped, headBalance, tailBalance, endTime] =
            await Promise.all([
              fcl.query({ cadence: GET_POOL_STATUS, args: (arg: Function, t: any) => [arg(String(id), t.UInt64)] }),
              fcl.query({ cadence: GET_TOSS_RESULT, args: (arg: Function, t: any) => [arg(String(id), t.UInt64)] }),
              fcl.query({ cadence: IS_COIN_FLIPPED, args: (arg: Function, t: any) => [arg(String(id), t.UInt64)] }),
              fcl.query({ cadence: GET_HEAD_BALANCE, args: (arg: Function, t: any) => [arg(String(id), t.UInt64)] }),
              fcl.query({ cadence: GET_TAIL_BALANCE, args: (arg: Function, t: any) => [arg(String(id), t.UInt64)] }),
              fcl.query({ cadence: GET_END_TIME, args: (arg: Function, t: any) => [arg(String(id), t.UInt64)] }),
            ])

          const status = Number(statusRaw)
          const headBal = parseFloat(headBalance)
          const tailBal = parseFloat(tailBalance)

          // Default user participation
          let userBetSide: 'Head' | 'Tail' | null = null
          let userBetAmount = 0
          let userClaimAmount = 0
          let userRewardClaimed = false

          if (userAddr) {
            const [headBet, tailBet] = await Promise.all([
              fcl.query({
                cadence: GET_USER_BET_HEAD,
                args: (arg: Function, t: any) => [arg(String(id), t.UInt64), arg(userAddr, t.Address)],
              }).catch(() => null),
              fcl.query({
                cadence: GET_USER_BET_TAIL,
                args: (arg: Function, t: any) => [arg(String(id), t.UInt64), arg(userAddr, t.Address)],
              }).catch(() => null),
            ])

            if (headBet !== null && headBet !== undefined) {
              userBetSide = 'Head'
              userBetAmount = parseFloat(headBet)
              // Fetch claim info if pool is closed
              if (status === 2) {
                const [claimAmt, claimed] = await Promise.all([
                  fcl.query({
                    cadence: GET_USER_HEAD_CLAIM,
                    args: (arg: Function, t: any) => [arg(String(id), t.UInt64), arg(userAddr, t.Address)],
                  }).catch(() => null),
                  fcl.query({
                    cadence: GET_USER_HEAD_CLAIMED,
                    args: (arg: Function, t: any) => [arg(String(id), t.UInt64), arg(userAddr, t.Address)],
                  }).catch(() => null),
                ])
                userClaimAmount = claimAmt ? parseFloat(claimAmt) : 0
                userRewardClaimed = claimed === true
              }
            } else if (tailBet !== null && tailBet !== undefined) {
              userBetSide = 'Tail'
              userBetAmount = parseFloat(tailBet)
              if (status === 2) {
                const [claimAmt, claimed] = await Promise.all([
                  fcl.query({
                    cadence: GET_USER_TAIL_CLAIM,
                    args: (arg: Function, t: any) => [arg(String(id), t.UInt64), arg(userAddr, t.Address)],
                  }).catch(() => null),
                  fcl.query({
                    cadence: GET_USER_TAIL_CLAIMED,
                    args: (arg: Function, t: any) => [arg(String(id), t.UInt64), arg(userAddr, t.Address)],
                  }).catch(() => null),
                ])
                userClaimAmount = claimAmt ? parseFloat(claimAmt) : 0
                userRewardClaimed = claimed === true
              }
            }
          }

          results.push({
            poolId: id,
            status,
            tossResult: typeof tossResult === 'string' ? tossResult : '',
            headBalance: headBal,
            tailBalance: tailBal,
            totalBalance: headBal + tailBal,
            endTime: Math.round(parseFloat(endTime)),
            isCoinFlipped: isCoinFlipped === true,
            userBetSide,
            userBetAmount,
            userClaimAmount,
            userRewardClaimed,
          })
        } catch (e) {
          console.error(`Failed to fetch pool ${id}:`, e)
          // Skip this pool rather than crashing
        }
      })
    )

    // Sort newest first (highest poolId first)
    results.sort((a, b) => b.poolId - a.poolId)
    setPools(results)
    onPoolsLoaded?.(results)
    setLoading(false)
  }, [currentPoolId, userAddr, onPoolsLoaded])

  useEffect(() => {
    fetchPoolData()
  }, [fetchPoolData])

  const handleClaim = async (poolId: number) => {
    setClaimingPoolId(poolId)
    try {
      const txId = await fcl.mutate({
        cadence: CLAIM_REWARD,
        args: (arg: Function, t: any) => [arg(String(poolId), t.UInt64)],
        payer: fcl.authz, proposer: fcl.authz, authorizations: [fcl.authz], limit: 999,
      })
      await fcl.tx(txId).onceSealed()
      // Optimistically mark as claimed
      setPools((prev) =>
        prev.map((p) =>
          p.poolId === poolId ? { ...p, userRewardClaimed: true } : p
        )
      )
    } catch (e: any) {
      console.error('Claim failed:', e)
    } finally {
      setClaimingPoolId(null)
    }
  }

  // Filter logic
  const filteredPools = myPoolsOnly
    ? pools.filter((p) => p.userBetSide !== null)
    : pools

  // Preview list (5 most recent) vs full modal list
  const previewPools = filteredPools.slice(0, 5)
  const displayPools = expanded ? filteredPools : previewPools

  // ============================================================
  // RENDER HELPERS
  // ============================================================
  const ResultBadge = ({ result }: { result: string }) => {
    if (!result) return (
      <span className="font-mono text-xs bg-degen-dark border border-degen-muted/30 text-degen-muted px-2 py-0.5 uppercase">
        PENDING
      </span>
    )
    const isHead = result === 'HEAD'
    return (
      <span className={`font-mono text-xs border px-2 py-0.5 uppercase font-bold ${
        isHead
          ? 'bg-neon-green/10 border-neon-green/40 neon-green-text'
          : 'bg-neon-red/10 border-neon-red/40 neon-red-text'
      }`}>
        {isHead ? 'HEADS' : 'TAILS'}
      </span>
    )
  }

  const UserResultBadge = ({ pool }: { pool: PoolRecord }) => {
    if (!pool.userBetSide) return null
    if (!pool.isCoinFlipped) {
      return <span className="font-mono text-xs text-degen-muted">Pending</span>
    }
    const won =
      (pool.tossResult === 'HEAD' && pool.userBetSide === 'Head') ||
      (pool.tossResult === 'TAIL' && pool.userBetSide === 'Tail')
    if (won) {
      return (
        <span className="font-mono text-xs neon-green-text font-bold">
          Won {pool.userClaimAmount > 0 ? `+${pool.userClaimAmount.toFixed(2)} FLOW` : ''}
        </span>
      )
    }
    return <span className="font-mono text-xs neon-red-text font-bold">Lost</span>
  }

  const canClaim = (pool: PoolRecord): boolean => {
    if (!pool.userBetSide || pool.status !== 2 || !pool.isCoinFlipped) return false
    if (pool.userRewardClaimed) return false
    const won =
      (pool.tossResult === 'HEAD' && pool.userBetSide === 'Head') ||
      (pool.tossResult === 'TAIL' && pool.userBetSide === 'Tail')
    return won
  }

  return (
    <section className="py-8 px-4 border-t border-neon-green/10">
      <div className="max-w-4xl mx-auto">
        {/* Header + filter toggle */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between mb-5 gap-3">
          <h2 className="font-display font-bold text-2xl tracking-widest text-degen-text uppercase text-center sm:text-left">
            PREVIOUS RESULTS
          </h2>
          <div className="flex gap-2 justify-center sm:justify-end">
            <button
              onClick={() => setMyPoolsOnly(false)}
              className={`font-display text-xs tracking-widest uppercase px-4 py-2 border transition-colors ${
                !myPoolsOnly
                  ? 'border-neon-green bg-neon-green/10 neon-green-text'
                  : 'border-degen-muted/30 text-degen-muted hover:border-neon-green/40'
              }`}
            >
              ALL POOLS
            </button>
            <button
              onClick={() => setMyPoolsOnly(true)}
              className={`font-display text-xs tracking-widest uppercase px-4 py-2 border transition-colors ${
                myPoolsOnly
                  ? 'border-neon-green bg-neon-green/10 neon-green-text'
                  : 'border-degen-muted/30 text-degen-muted hover:border-neon-green/40'
              }`}
            >
              MY POOLS
            </button>
          </div>
        </div>

        {/* Loading skeleton */}
        {loading && (
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="bg-degen-panel border border-neon-green/10 p-4 animate-pulse">
                <div className="h-4 bg-degen-dark rounded w-1/3 mb-2" />
                <div className="h-3 bg-degen-dark rounded w-1/2" />
              </div>
            ))}
          </div>
        )}

        {/* Empty states */}
        {!loading && filteredPools.length === 0 && myPoolsOnly && (
          <p className="font-mono text-sm text-degen-muted text-center py-8">
            {userAddr ? "You haven't participated in any pools yet." : 'Connect your wallet to see your pools.'}
          </p>
        )}
        {!loading && filteredPools.length === 0 && !myPoolsOnly && (
          <p className="font-mono text-sm text-degen-muted text-center py-8">
            No completed pools yet.
          </p>
        )}

        {/* Pool cards */}
        {!loading && displayPools.map((pool) => (
          <div
            key={pool.poolId}
            className="bg-degen-panel border border-neon-green/10 p-4 mb-3 grid grid-cols-12 items-start gap-2"
          >
            {/* Coin image */}
            <div className="col-span-2 flex items-center pt-1">
              <img
                src={pool.tossResult === 'HEAD' ? '/coin-heads.png' : pool.tossResult === 'TAIL' ? '/coin-tails.png' : '/coin-tails.png'}
                alt="Coin"
                className="h-10 w-10"
              />
            </div>

            {/* Main info */}
            <div className="col-span-7 flex flex-col gap-1">
              <div className="flex items-center gap-2 flex-wrap">
                <span className="font-display font-bold text-degen-text text-sm">
                  POOL #{String(pool.poolId).padStart(5, '0')}
                </span>
                <ResultBadge result={pool.tossResult} />
                {pool.poolId === currentPoolId && pool.status === 0 && (
                  <span className="font-mono text-xs text-neon-amber border border-neon-amber/40 px-2 py-0.5 uppercase">
                    LIVE
                  </span>
                )}
              </div>

              <p className="font-mono text-xs text-degen-muted">{formatTimestamp(pool.endTime)}</p>

              {/* Head / tail split */}
              <div className="flex items-center gap-3 mt-1">
                <span className="font-mono text-xs">
                  <span className="neon-green-text">{pool.headBalance.toFixed(1)}</span>
                  <span className="text-degen-muted"> H</span>
                </span>
                <span className="text-degen-muted/40 text-xs">↔</span>
                <span className="font-mono text-xs">
                  <span className="neon-red-text">{pool.tailBalance.toFixed(1)}</span>
                  <span className="text-degen-muted"> T</span>
                </span>
              </div>

              {/* User participation */}
              {pool.userBetSide && (
                <div className="mt-1 flex flex-col gap-0.5">
                  <span className="font-mono text-xs text-degen-muted">
                    You bet <span className="text-degen-text font-bold">{pool.userBetAmount.toFixed(1)} FLOW</span>
                    {' on '}
                    <span className={pool.userBetSide === 'Head' ? 'neon-green-text' : 'neon-red-text'}>
                      {pool.userBetSide === 'Head' ? 'HEADS' : 'TAILS'}
                    </span>
                  </span>
                  <UserResultBadge pool={pool} />
                  {pool.userRewardClaimed && (
                    <span className="font-mono text-xs neon-green-text">Claimed ✓</span>
                  )}
                </div>
              )}
            </div>

            {/* Right column: total + claim */}
            <div className="col-span-3 flex flex-col items-end gap-2">
              <div className="flex items-center gap-1">
                <img src="/flow.png" alt="Flow" className="h-4 w-4" />
                <span className="font-mono text-sm font-bold text-degen-text">
                  {pool.totalBalance.toFixed(1)}
                </span>
              </div>

              {canClaim(pool) && (
                <button
                  onClick={() => handleClaim(pool.poolId)}
                  disabled={claimingPoolId === pool.poolId}
                  className="font-display text-xs tracking-widest uppercase bg-neon-green text-degen-black px-3 py-1.5 hover:shadow-neon-green transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {claimingPoolId === pool.poolId ? '...' : 'CLAIM'}
                </button>
              )}
            </div>
          </div>
        ))}

        {/* Show more / collapse */}
        {!loading && filteredPools.length > 5 && (
          <button
            className="font-display text-xs tracking-widest text-neon-green hover:text-neon-green/70 uppercase mx-auto my-4 p-2 block transition-colors"
            onClick={() => setExpanded((prev) => !prev)}
          >
            {expanded ? 'SHOW LESS' : `SHOW ALL ${filteredPools.length} RESULTS`}
          </button>
        )}

        {/* Refresh button */}
        {!loading && (
          <div className="text-center mt-2">
            <button
              onClick={fetchPoolData}
              className="font-mono text-xs text-degen-muted hover:text-degen-text transition-colors uppercase tracking-widest"
            >
              ↻ Refresh
            </button>
          </div>
        )}
      </div>
    </section>
  )
}

export default PreviousWinners

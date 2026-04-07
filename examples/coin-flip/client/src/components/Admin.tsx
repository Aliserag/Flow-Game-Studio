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
      <div className="p-8 text-center">
        <Header />
        <p className="mt-8 text-gray-600">Connect with the admin wallet to access this page.</p>
        {!user?.loggedIn && (
          <button
            onClick={() => fcl.authenticate()}
            className="mt-4 bg-black text-white px-6 py-2 rounded-full"
          >
            Connect Wallet
          </button>
        )}
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
    <div className="min-h-screen bg-white">
      <Header />
      <div className="max-w-2xl mx-auto p-8">
        <h1 className="text-3xl font-bold mb-6">Admin Panel</h1>
        <p className="text-gray-600 mb-4">Connected as: <code className="bg-gray-100 px-2 py-1 rounded">{user.addr}</code></p>
        <button
          onClick={tossTheCoin}
          className="bg-green-600 text-white font-bold py-3 px-8 rounded-lg hover:bg-green-700 transition"
        >
          TOSS THE COIN
        </button>
        {status && <p className="mt-4 text-gray-700 font-medium">{status}</p>}
        <div className="mt-8 p-4 bg-gray-100 rounded-lg">
          <h2 className="font-bold mb-2">Instructions</h2>
          <ol className="list-decimal list-inside space-y-1 text-sm text-gray-700">
            <li>Wait for the pool betting window to close (5 min on emulator)</li>
            <li>Click TOSS THE COIN to determine winner</li>
            <li>A new pool is automatically created after each toss</li>
            <li>Winners can claim at the main page</li>
          </ol>
        </div>
      </div>
    </div>
  )
}

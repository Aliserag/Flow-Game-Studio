import { useState, useCallback, useRef } from 'react'
import * as fcl from '@onflow/fcl-react-native'
import type { ArgumentFunction } from '../types'

export type TxStatus = 'idle' | 'pending' | 'sealed' | 'error'

interface UseFlowTransactionReturn {
  status: TxStatus
  txId: string | null
  errorMessage: string | null
  sendTransaction: (cadence: string, args?: ArgumentFunction) => Promise<string | null>
  reset: () => void
}

export function useFlowTransaction(): UseFlowTransactionReturn {
  const [status, setStatus] = useState<TxStatus>('idle')
  const [txId, setTxId] = useState<string | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const isPendingRef = useRef(false)

  const sendTransaction = useCallback(async (
    cadence: string,
    args?: ArgumentFunction,
  ): Promise<string | null> => {
    // Guard against concurrent calls — a second call while one is in-flight
    // returns null immediately without mutating state.
    if (isPendingRef.current) return null
    isPendingRef.current = true

    setStatus('pending')
    setTxId(null)
    setErrorMessage(null)

    try {
      const id = await fcl.mutate({
        cadence,
        args,
        proposer:       fcl.authz,
        payer:          fcl.authz,
        authorizations: [fcl.authz],
        limit:          100, // compute limit — increase for complex transactions
      })
      setTxId(id)

      // Wait for the transaction to be sealed on-chain
      await fcl.tx(id).onceSealed()
      setStatus('sealed')
      return id
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err)
      setErrorMessage(message)
      setStatus('error')
      return null
    } finally {
      // Always release the lock — status never gets stuck at 'pending'
      isPendingRef.current = false
    }
  }, [])

  const reset = useCallback(() => {
    setStatus('idle')
    setTxId(null)
    setErrorMessage(null)
  }, [])

  return { status, txId, errorMessage, sendTransaction, reset }
}

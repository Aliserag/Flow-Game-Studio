import { useState, useCallback } from 'react'
import * as fcl from '@onflow/fcl-react-native'
import type { ArgumentFunction } from '../types'

export type ScriptStatus = 'idle' | 'loading' | 'success' | 'error'

interface UseFlowScriptReturn<T> {
  data: T | null
  status: ScriptStatus
  errorMessage: string | null
  runScript: (cadence: string, args?: ArgumentFunction) => Promise<T | null>
  reset: () => void
}

export function useFlowScript<T = unknown>(): UseFlowScriptReturn<T> {
  const [data, setData] = useState<T | null>(null)
  const [status, setStatus] = useState<ScriptStatus>('idle')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const runScript = useCallback(async (
    cadence: string,
    args?: ArgumentFunction,
  ): Promise<T | null> => {
    setStatus('loading')
    setData(null)
    setErrorMessage(null)

    try {
      // fcl.query executes a read-only Cadence script — no transaction, no gas
      const result: T = await fcl.query({ cadence, args })
      setData(result)
      setStatus('success')
      return result
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err)
      setErrorMessage(message)
      setStatus('error')
      return null
    }
  }, [])

  const reset = useCallback(() => {
    setData(null)
    setStatus('idle')
    setErrorMessage(null)
  }, [])

  return { data, status, errorMessage, runScript, reset }
}

// Wraps FCL mutate to route through the sponsor payer service
import * as fcl from '@onflow/fcl'

const SPONSOR_SERVICE_URL = 'http://localhost:3001/sponsor'

export interface SponsoredMutateArgs {
  cadence: string
  args?: unknown
  limit?: number
}

export async function sponsoredMutate(txArgs: SponsoredMutateArgs): Promise<string> {
  const txId = await fcl.mutate({
    cadence: txArgs.cadence,
    args: txArgs.args ?? fcl.args([]),
    limit: txArgs.limit ?? 999,
    payer: async (account: Record<string, unknown>) => {
      const response = await fetch(SPONSOR_SERVICE_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ account })
      })
      if (!response.ok) {
        throw new Error(`Sponsor service error: ${response.statusText}`)
      }
      return response.json()
    }
  })
  return txId
}

export async function waitForSealed(txId: string): Promise<void> {
  const result = await fcl.tx(txId).onceSealed()
  if (result.errorMessage) {
    throw new Error(`Transaction failed: ${result.errorMessage}`)
  }
}

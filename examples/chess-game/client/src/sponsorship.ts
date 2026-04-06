import * as fcl from '@onflow/fcl'

export interface SponsoredMutateArgs {
  cadence: string
  args?: unknown
  limit?: number
}

// Wraps fcl.mutate with a consistent interface.
// Note: sponsor payer service not yet implemented — transactions are signed by the connected wallet.
export async function sponsoredMutate(txArgs: SponsoredMutateArgs): Promise<string> {
  return fcl.mutate({
    cadence: txArgs.cadence,
    args: txArgs.args ?? fcl.args([]),
    limit: txArgs.limit ?? 999,
  })
}

export async function waitForSealed(txId: string): Promise<void> {
  const result = await fcl.tx(txId).onceSealed()
  if (result.errorMessage) {
    throw new Error(`Transaction failed: ${result.errorMessage}`)
  }
}

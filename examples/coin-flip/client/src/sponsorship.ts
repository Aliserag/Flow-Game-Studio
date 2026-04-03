/// sponsorship.ts — Gasless transaction wrapper using a payer service.
///
/// The sponsor-service/server.ts co-signs transactions as fee payer so
/// players never need FLOW tokens.  Falls back to user-pays if the
/// sponsor service is unavailable (e.g. running client standalone).
import * as fcl from "@onflow/fcl"

const SPONSOR_URL = "http://localhost:3001"

/// Authorization function that fetches a payer signature from the sponsor service.
/// Returns a standard FCL AuthorizationObject compatible with fcl.mutate().
async function sponsorAuthz(account: Record<string, unknown>): Promise<Record<string, unknown>> {
  try {
    const resp = await fetch(`${SPONSOR_URL}/authorize`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ role: "payer" }),
    })
    if (!resp.ok) throw new Error(`Sponsor service returned ${resp.status}`)

    const { address, keyId } = (await resp.json()) as {
      address: string
      keyId: number
    }

    // Return authorization that tells FCL to use the sponsor's account for fees.
    // For emulator dev, the dev-wallet handles the actual signing automatically
    // when it sees this account referenced.  In production, the server would
    // return a full signed voucher.
    return {
      ...account,
      addr: fcl.withPrefix(address),
      keyId,
      signingFunction: async (signable: { message: string }) => {
        // Ask the sponsor service to sign the envelope.
        const signResp = await fetch(`${SPONSOR_URL}/sign`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ message: signable.message }),
        })
        if (!signResp.ok) throw new Error("Sponsor signing failed")
        const { signature } = (await signResp.json()) as { signature: string }
        return { addr: fcl.withPrefix(address), keyId, signature }
      },
    }
  } catch {
    // Sponsor unavailable — fall back to user paying their own gas.
    console.warn("[sponsorship] Sponsor service unavailable, falling back to user-pays")
    return fcl.authz(account)
  }
}

/// Mutate the chain with optional sponsorship.
///
/// Usage:
///   const txId = await sponsoredMutate({
///     cadence: commitTxCode,
///     args: fcl.args([fcl.arg(hashHex, t.String), fcl.arg(choice, t.Bool)]),
///   })
export async function sponsoredMutate(args: {
  cadence: string
  args?: ReturnType<typeof fcl.args>
  authorizations?: typeof fcl.authz[]
  limit?: number
}): Promise<string> {
  return fcl.mutate({
    cadence: args.cadence,
    args: args.args ?? fcl.args([]),
    proposer: fcl.authz,
    payer: sponsorAuthz,
    authorizations: args.authorizations ?? [fcl.authz],
    limit: args.limit ?? 999,
  })
}

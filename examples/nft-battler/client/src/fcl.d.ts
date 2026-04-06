// fcl.d.ts — Type declarations for @onflow/fcl (no official @types package).
// Minimal types covering the FCL surface used in this project.

declare module "@onflow/fcl" {
  // Auth
  export function authenticate(): Promise<void>
  export function unauthenticate(): Promise<void>

  // Current user subscription
  export const currentUser: {
    subscribe: (callback: (user: { addr?: string } | null) => void) => () => void
  }

  // Script query
  export function query(opts: {
    cadence: string
    args?: (arg: typeof fcl.arg, t: typeof fcl.t) => unknown[]
    limit?: number
  }): Promise<unknown>

  // Transaction mutate
  export function mutate(opts: {
    cadence: string
    args?: (arg: typeof fcl.arg, t: typeof fcl.t) => unknown[]
    limit?: number
  }): Promise<string>

  // Transaction status
  export function tx(txId: string): {
    onceSealed: () => Promise<{ status: number; errorMessage: string }>
  }

  // FCL argument builder
  export function arg(value: unknown, type: unknown): unknown

  // FCL types
  export const t: {
    Address: unknown
    String: unknown
    UInt64: unknown
    UInt8: unknown
    UFix64: unknown
    Bool: unknown
    Optional: (type: unknown) => unknown
    Array: (type: unknown) => unknown
  }

  // FCL config
  export function config(opts: Record<string, string>): void
}

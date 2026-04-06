/// Type declarations for Flow modules that don't ship complete TypeScript definitions.

declare module "@onflow/fcl" {
  export function config(opts: Record<string, unknown>): void
  export function authenticate(): Promise<void>
  export function unauthenticate(): void
  export function withPrefix(address: string): string
  export function args(a: unknown[]): unknown[]
  export function arg(value: unknown, type: unknown): unknown
  export function mutate(opts: {
    cadence: string
    args?: unknown
    proposer?: unknown
    payer?: unknown
    authorizations?: unknown[]
    limit?: number
  }): Promise<string>
  export function query(opts: {
    cadence: string
    args?: unknown
  }): Promise<unknown>
  export function tx(txId: string): {
    onceSealed(): Promise<{ events: Array<{ type: string; data: Record<string, unknown> }> }>
  }
  export const authz: ((account: Record<string, unknown>) => Promise<Record<string, unknown>>) &
    Record<string, unknown>
  export const currentUser: {
    subscribe(cb: (user: { addr?: string; loggedIn?: boolean }) => void): () => void
  }
}

declare module "@onflow/types" {
  export const String: unique symbol
  export const Bool: unique symbol
  export const UInt64: unique symbol
  export const UInt256: unique symbol
  export const Address: unique symbol
  export const UInt8: unique symbol
  export const Int: unique symbol
}

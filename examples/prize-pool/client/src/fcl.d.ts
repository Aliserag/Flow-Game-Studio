/// fcl.d.ts — Minimal type declarations for @onflow/fcl.
/// The official @onflow/fcl package ships a .js bundle without TypeScript types.
/// This stub gives the compiler enough to be happy.

declare module "@onflow/fcl" {
  export interface User {
    addr?: string
    loggedIn?: boolean
    cid?: string
    expiresAt?: number
    f_type?: string
    f_vsn?: string
    services?: unknown[]
  }

  export interface CurrentUser {
    subscribe(callback: (user: User) => void): () => void
    snapshot(): Promise<User>
    authenticate(): Promise<User>
    unauthenticate(): void
    authorization: unknown
    signUserMessage(message: string): Promise<unknown>
  }

  export interface ScriptArgs {
    (arg: typeof fcl.arg, t: typeof fcl.t): unknown[]
  }

  export interface MutateArgs {
    cadence: string
    args?: ScriptArgs
    proposer?: unknown
    payer?: unknown
    authorizations?: unknown[]
    limit?: number
  }

  export interface QueryArgs {
    cadence: string
    args?: ScriptArgs
  }

  export const currentUser: CurrentUser
  export const authz: unknown

  export function config(opts: Record<string, string>): void
  export function authenticate(): Promise<User>
  export function unauthenticate(): void
  export function mutate(args: MutateArgs): Promise<string>
  export function query(args: QueryArgs): Promise<unknown>
  export function arg(value: unknown, type: unknown): unknown

  export const t: {
    String: unknown
    UInt64: unknown
    UInt256: unknown
    Address: unknown
    Bool: unknown
    Array: (type: unknown) => unknown
    Optional: (type: unknown) => unknown
  }
}

declare module '@onflow/fcl' {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export function config(opts: Record<string, string>): void
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export function query(opts: Record<string, any>): Promise<any>
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export function mutate(opts: Record<string, any>): Promise<string>
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export function tx(txId: string): { onceSealed(): Promise<{ errorMessage?: string }> }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export function args(a: any[]): any[]
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export const arg: any
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export const t: any
  export function unauthenticate(): void
  export const currentUser: {
    subscribe(cb: (user: { addr?: string }) => void): () => void
  }
}

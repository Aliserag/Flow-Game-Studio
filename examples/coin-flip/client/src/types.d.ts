// FCL doesn't ship with TypeScript declarations; declare it as any-typed.
declare module '@onflow/fcl' {
  const fcl: any
  export = fcl
  export const config: any
  export const currentUser: any
  export const authenticate: any
  export const unauthenticate: any
  export const mutate: any
  export const query: any
  export const send: any
  export const decode: any
  export const build: any
  export const getAccount: any
  export const getBlock: any
  export const getTransaction: any
  export const getTransactionStatus: any
  export const subscribe: any
  export const tx: any
  export const script: any
  export const transaction: any
  export const args: any
  export const arg: any
  export const proposer: any
  export const authorizations: any
  export const authorization: any
  export const payer: any
  export const limit: any
  export const cdc: any
  export const t: any
  export default fcl
}

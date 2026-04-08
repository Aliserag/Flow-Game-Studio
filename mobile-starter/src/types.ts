import type * as fcl from '@onflow/fcl-react-native'

// Shared argument builder type used by useFlowScript and useFlowTransaction.
// Example: (arg, t) => [arg('10.0', t.UFix64)]
export type ArgumentFunction = (arg: typeof fcl.arg, t: typeof fcl.t) => fcl.Argument[]

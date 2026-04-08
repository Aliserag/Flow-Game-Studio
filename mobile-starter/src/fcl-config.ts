import { config } from '@onflow/fcl-react-native'

// FCL configuration for Flow testnet + WalletConnect v2.
//
// Required env vars (set in .env.local):
//   EXPO_PUBLIC_WC_PROJECT_ID  — from https://cloud.walletconnect.com
//   EXPO_PUBLIC_FLOW_NETWORK   — 'testnet' | 'mainnet' (default: testnet)

const network = process.env.EXPO_PUBLIC_FLOW_NETWORK ?? 'testnet'

if (network !== 'testnet' && network !== 'mainnet') {
  throw new Error(
    `Unknown EXPO_PUBLIC_FLOW_NETWORK: "${network}". Must be 'testnet' or 'mainnet'.`,
  )
}

const ACCESS_NODES = {
  testnet: 'https://rest-testnet.onflow.org',
  mainnet: 'https://rest-mainnet.onflow.org',
} as const

const DISCOVERY = {
  testnet: {
    wallet: 'https://fcl-discovery.onflow.org/testnet/authn',
    authn:  'https://fcl-discovery.onflow.org/api/testnet/authn',
  },
  mainnet: {
    wallet: 'https://fcl-discovery.onflow.org/authn',
    authn:  'https://fcl-discovery.onflow.org/api/authn',
  },
} as const

// Core contract addresses — referenced in Cadence as `0xFungibleToken`, `0xFlowToken`.
// FCL replaces these aliases automatically so the same Cadence works on both networks.
const CONTRACT_ADDRESSES = {
  testnet: {
    FungibleToken: '0x9a0766d93b6608b7',
    FlowToken:     '0x7e60df042a9c0868',
  },
  mainnet: {
    FungibleToken: '0xf233dcee88fe0abe',
    FlowToken:     '0x1654653399040a61',
  },
} as const

config({
  // Network
  'flow.network':   network,
  'accessNode.api': ACCESS_NODES[network],

  // Wallet discovery — enables the FCL ConnectModal wallet list
  'discovery.wallet':          DISCOVERY[network].wallet,
  'discovery.authn.endpoint':  DISCOVERY[network].authn,

  // WalletConnect v2 — activates automatically when projectId is present
  'walletconnect.projectId': (() => {
    const id = process.env.EXPO_PUBLIC_WC_PROJECT_ID
    if (!id) throw new Error('EXPO_PUBLIC_WC_PROJECT_ID is required. Get one at https://cloud.walletconnect.com')
    return id
  })(),

  // Contract address aliases — use `0xFungibleToken` etc. in Cadence scripts
  '0xFungibleToken': CONTRACT_ADDRESSES[network].FungibleToken,
  '0xFlowToken':     CONTRACT_ADDRESSES[network].FlowToken,

  // App metadata shown inside wallets during auth — TODO: replace with your app's details
  'app.detail.title':       'YOUR APP NAME',
  'app.detail.icon':        'https://YOUR_APP_ICON_URL',
  'app.detail.description': 'YOUR APP DESCRIPTION',
  'app.detail.url':         'https://YOUR_APP_URL',
})

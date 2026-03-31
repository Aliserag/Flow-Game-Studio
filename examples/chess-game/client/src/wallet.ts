import * as fcl from '@onflow/fcl'

export function configureFCL(): void {
  fcl.config({
    'accessNode.api': 'http://localhost:8080',
    'flow.network': 'emulator',
    'discovery.wallet': 'http://localhost:8701/fcl/authn',
    'app.detail.title': 'Chess on Flow',
    'app.detail.icon': 'https://chess-on-flow.example/icon.png'
  })
}

export interface AppAccount {
  address: string
  keyIndex: number
  privateKey: string
}

export async function getOrCreateAppAccount(): Promise<AppAccount> {
  const stored = localStorage.getItem('chess_app_account')
  if (stored) {
    return JSON.parse(stored) as AppAccount
  }
  const response = await fetch('http://localhost:3001/create-account', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  })
  if (!response.ok) {
    throw new Error('Failed to create app account')
  }
  const account = await response.json() as AppAccount
  localStorage.setItem('chess_app_account', JSON.stringify(account))
  return account
}

export function getCurrentUser(): { subscribe(cb: (user: { addr?: string }) => void): () => void } {
  return fcl.currentUser
}

export function signOut(): void {
  fcl.unauthenticate()
  localStorage.removeItem('chess_app_account')
}

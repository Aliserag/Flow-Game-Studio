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

export function getCurrentUser(): { subscribe(cb: (user: { addr?: string }) => void): () => void } {
  return fcl.currentUser
}

export function signOut(): void {
  fcl.unauthenticate()
  localStorage.removeItem('chess_app_account')
}

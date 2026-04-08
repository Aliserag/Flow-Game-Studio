import { useState, useEffect } from 'react'
import * as fcl from '@onflow/fcl-react-native'

export interface FlowUser {
  loggedIn: boolean | null  // null = loading, false = logged out, true = logged in
  addr: string | undefined
  cid: string | undefined   // composite identifier
}

interface UseFlowAuthReturn {
  user: FlowUser
  isLoading: boolean        // true while auth state is being resolved from storage
  isAuthenticated: boolean
  login: () => void
  logout: () => void
}

export function useFlowAuth(): UseFlowAuthReturn {
  const [user, setUser] = useState<FlowUser>({ loggedIn: null, addr: undefined, cid: undefined })

  useEffect(() => {
    // currentUser.subscribe fires immediately with the stored auth state,
    // then again on any login/logout. Returns an unsubscribe function.
    const unsubscribe = fcl.currentUser.subscribe((u: FlowUser) => setUser(u))
    return unsubscribe
  }, [])

  return {
    user,
    isLoading:       user.loggedIn === null,
    isAuthenticated: user.loggedIn === true,
    login:           () => fcl.authenticate(),
    logout:          () => fcl.unauthenticate(),
  }
}

// IMPORTANT: polyfills.ts MUST be the very first import — before React, FCL,
// or any other module. Metro's inlineRequires can reorder lazy imports, so
// centralising polyfills here and importing first is the only reliable strategy.
import './src/polyfills'

// FCL config must be imported before any FCL calls.
import './src/fcl-config'

import React, { useCallback } from 'react'
import {
  ActivityIndicator,
  Button,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native'
import { ConnectModalProvider } from '@onflow/fcl-react-native'

import { useFlowAuth } from './src/hooks/useFlowAuth'
import { useFlowScript } from './src/hooks/useFlowScript'
import { useFlowTransaction } from './src/hooks/useFlowTransaction'

// ---------------------------------------------------------------------------
// Example Cadence scripts & transactions
//
// Contract addresses use FCL aliases (e.g. 0xFungibleToken) configured in
// fcl-config.ts — the same Cadence works on testnet and mainnet unchanged.
// ---------------------------------------------------------------------------

const GET_FLOW_BALANCE = `
  import FungibleToken from 0xFungibleToken
  import FlowToken from 0xFlowToken

  access(all) fun main(address: Address): UFix64 {
    let account = getAccount(address)
    let vaultRef = account.capabilities
      .borrow<&{FungibleToken.Balance}>(/public/flowTokenBalance)
    return vaultRef?.balance ?? 0.0
  }
`

const GREET_TRANSACTION = `
  transaction(message: String) {
    prepare(signer: &Account) {
      log("Hello from ".concat(signer.address.toString()).concat(": ").concat(message))
    }
  }
`

// ---------------------------------------------------------------------------
// Inner screen — rendered inside ConnectModalProvider
// ---------------------------------------------------------------------------

function HomeScreen() {
  const { user, isLoading, isAuthenticated, login, logout } = useFlowAuth()
  const {
    data: balance,
    status: scriptStatus,
    errorMessage: scriptError,
    runScript,
  } = useFlowScript<string>()
  const {
    status: txStatus,
    txId,
    errorMessage: txError,
    sendTransaction,
  } = useFlowTransaction()

  const handleFetchBalance = useCallback(async () => {
    if (!user.addr) return
    await runScript(GET_FLOW_BALANCE, (arg, t) => [arg(user.addr!, t.Address)])
  }, [user.addr, runScript])

  const handleGreet = useCallback(async () => {
    await sendTransaction(GREET_TRANSACTION, (arg, t) => [arg('Hello, Flow!', t.String)])
  }, [sendTransaction])

  if (isLoading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" />
        <Text style={styles.subtitle}>Loading wallet state…</Text>
      </View>
    )
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Flow Mobile Starter</Text>

      {/* ── Auth ── */}
      <View style={styles.section}>
        <Text style={styles.heading}>Authentication</Text>
        {isAuthenticated ? (
          <>
            <Text style={styles.address}>✅ {user.addr}</Text>
            <Button title="Log Out" onPress={logout} color="#c0392b" />
          </>
        ) : (
          <Button title="Connect Wallet" onPress={login} color="#2980b9" />
        )}
      </View>

      {/* ── Script (read) ── */}
      {isAuthenticated && (
        <View style={styles.section}>
          <Text style={styles.heading}>Read FLOW Balance (script)</Text>
          <Button
            title={scriptStatus === 'loading' ? 'Fetching…' : 'Fetch Balance'}
            onPress={handleFetchBalance}
            disabled={scriptStatus === 'loading'}
          />
          {balance !== null && (
            <Text style={styles.result}>Balance: {balance} FLOW</Text>
          )}
          {scriptError && <Text style={styles.error}>{scriptError}</Text>}
        </View>
      )}

      {/* ── Transaction (write) ── */}
      {isAuthenticated && (
        <View style={styles.section}>
          <Text style={styles.heading}>Send Transaction (write)</Text>
          <Button
            title={txStatus === 'pending' ? 'Sending…' : 'Send Greeting Tx'}
            onPress={handleGreet}
            disabled={txStatus === 'pending'}
          />
          {txStatus === 'sealed' && txId && (
            <Text style={styles.result}>✅ Sealed: {txId.slice(0, 16)}…</Text>
          )}
          {txError && <Text style={styles.error}>{txError}</Text>}
        </View>
      )}
    </ScrollView>
  )
}

// ---------------------------------------------------------------------------
// Root — ConnectModalProvider must wrap the entire tree
// ---------------------------------------------------------------------------

export default function App() {
  return (
    <ConnectModalProvider>
      <HomeScreen />
    </ConnectModalProvider>
  )
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const styles = StyleSheet.create({
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 12,
  },
  container: {
    padding: 24,
    paddingTop: 60,
    gap: 24,
  },
  title: {
    fontSize: 26,
    fontWeight: '700',
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 14,
    color: '#666',
  },
  heading: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 8,
  },
  section: {
    backgroundColor: '#f5f5f5',
    borderRadius: 12,
    padding: 16,
    gap: 8,
  },
  address: {
    fontFamily: Platform.OS === 'ios' ? 'Courier New' : 'monospace',
    fontSize: 13,
    color: '#27ae60',
    marginBottom: 4,
  },
  result: {
    fontFamily: Platform.OS === 'ios' ? 'Courier New' : 'monospace',
    fontSize: 13,
    color: '#2c3e50',
    marginTop: 4,
  },
  error: {
    fontSize: 13,
    color: '#c0392b',
    marginTop: 4,
  },
})

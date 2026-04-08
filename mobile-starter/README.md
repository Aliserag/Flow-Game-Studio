# Flow Mobile Starter

A production-ready scaffold for building Flow blockchain mobile games with
React Native (Expo SDK 52) + `@onflow/fcl-react-native` + WalletConnect v2.

## What You Get

| File | Purpose |
|------|---------|
| `App.tsx` | Root with `ConnectModalProvider` wrapping pattern |
| `src/polyfills.ts` | Node.js shims — **must be first import** |
| `src/fcl-config.ts` | FCL config for testnet/mainnet + WalletConnect + contract aliases |
| `src/types.ts` | Shared `ArgumentFunction` type for hooks |
| `src/hooks/useFlowAuth.ts` | Login / logout / auth state |
| `src/hooks/useFlowScript.ts` | Read-only Cadence script execution |
| `src/hooks/useFlowTransaction.ts` | Signed transaction submission + status |
| `metro.config.js` | Metro polyfill mappings for FCL + WC |
| `app.json` | Expo config with deep link scheme + New Architecture |
| `eas.json` | EAS Build profiles (development / preview / production) |

## Prerequisites

1. **Node 20+** and **Expo CLI**: `npm install -g expo-cli eas-cli`
2. **WalletConnect project ID**: create a free project at
   [cloud.walletconnect.com](https://cloud.walletconnect.com)
3. **EAS account** (free): `eas login` — required for the custom dev client

> ⚠️ **Expo Go will not work.** FCL React Native and WalletConnect require
> native modules that aren't in Expo Go. You need a custom development client
> built via EAS Build.

## Quick Start

```bash
# 1. Install dependencies
npm install

# 2. Configure environment
cp .env.example .env.local
# Edit .env.local — set EXPO_PUBLIC_WC_PROJECT_ID
# Expo CLI auto-loads .env.local at startup; restart expo start after any change

# 3. Update app metadata in src/fcl-config.ts
#    Replace the TODO placeholders (title, icon, description, url)

# 4. Add your app icons to assets/ (see assets/README.md)

# 5. Build a custom dev client (first time only, ~5 min)
eas build --profile development --platform ios   # or android
# Install the resulting .ipa / .apk on your device / simulator

# 6. Start the Expo dev server
npx expo start --dev-client

# 7. Open the app on your device (scan QR or press 'i'/'a')
```

## How It Works

### Polyfill Ordering (Critical)

Expo SDK 52 enables `inlineRequires` by default. This means module-level code
can run before your imports if polyfills are scattered. `polyfills.ts` centralises
all shims and **must be the very first import** in `App.tsx`:

```typescript
import './src/polyfills'  // line 1 of App.tsx — never move this
import './src/fcl-config'
```

### WalletConnect Activation

FCL activates WalletConnect v2 automatically when `walletconnect.projectId` is
set in the FCL config. No extra WC provider setup needed — just wrap your app in
`<ConnectModalProvider>` (already done in `App.tsx`).

### Contract Address Aliases

`fcl-config.ts` registers contract address aliases for both networks:

```typescript
'0xFungibleToken': '0x9a0766d93b6608b7',  // testnet
'0xFlowToken':     '0x7e60df042a9c0868',
```

Use these in Cadence with symbolic names — FCL resolves the correct address
automatically for whichever network is configured:

```cadence
import FungibleToken from 0xFungibleToken  // works on testnet AND mainnet
```

Add your own game contract aliases to `fcl-config.ts` the same way.

### Auth Flow

```typescript
const { user, isAuthenticated, login, logout } = useFlowAuth()

// user.loggedIn === null  → loading (resolving from AsyncStorage)
// user.loggedIn === false → logged out
// user.loggedIn === true  → logged in; user.addr has the Flow address
```

### Reading On-Chain Data (Scripts)

```typescript
const { data, status, runScript } = useFlowScript<string>()

await runScript(
  `access(all) fun main(addr: Address): String { return addr.toString() }`,
  (arg, t) => [arg('0xABCD1234', t.Address)],
)
// data is now '0xABCD1234'
```

### Sending Transactions

```typescript
const { status, txId, sendTransaction } = useFlowTransaction()

const id = await sendTransaction(
  `transaction(msg: String) { prepare(s: &Account) { log(msg) } }`,
  (arg, t) => [arg('Hello, Flow!', t.String)],
)
// status transitions: idle → pending → sealed (or error)
// sendTransaction is guarded — concurrent calls return null without state mutation
```

## Switching Networks

In `.env.local`:

```
EXPO_PUBLIC_FLOW_NETWORK=mainnet
```

FCL config switches access node, discovery endpoints, and all contract addresses
automatically. **Restart `npx expo start` completely** (not just save) after
changing env vars — Metro does not hot-reload environment variables.

## Customising App Metadata

Open `src/fcl-config.ts` and replace the TODO placeholders:

```typescript
'app.detail.title':       'YOUR APP NAME',
'app.detail.icon':        'https://YOUR_APP_ICON_URL',
'app.detail.description': 'YOUR APP DESCRIPTION',
'app.detail.url':         'https://YOUR_APP_URL',
```

These values appear inside wallets during the authentication handshake.

## Building for Production

```bash
# iOS
eas build --profile production --platform ios

# Android
eas build --profile production --platform android
```

See `eas.json` for available build profiles and Expo's EAS Build docs to
configure signing credentials.

> Before going to production, set `"requireCommit": true` in `eas.json`
> to ensure builds never include uncommitted changes.

## Project Structure

```
mobile-starter/
├── App.tsx                       # Root — ConnectModalProvider wraps the tree
├── index.js                      # Expo entry point (registerRootComponent)
├── app.json                      # Expo config (scheme, New Architecture)
├── eas.json                      # EAS Build profiles
├── metro.config.js               # Node polyfill mappings
├── package.json
├── tsconfig.json
├── env.example                   # Copy to .env.local
├── assets/                       # Replace with your app's icons + splash
└── src/
    ├── polyfills.ts              # Must be first import in App.tsx
    ├── fcl-config.ts             # FCL + WalletConnect + contract aliases
    ├── types.ts                  # Shared ArgumentFunction type
    └── hooks/
        ├── useFlowAuth.ts        # Authentication state
        ├── useFlowScript.ts      # Read Cadence (no wallet needed)
        └── useFlowTransaction.ts # Write Cadence (wallet required)
```

## Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ConnectModal` doesn't open | `ConnectModalProvider` missing | Wrap root in `<ConnectModalProvider>` |
| Crypto errors at startup | Wrong polyfill order | Ensure `polyfills.ts` is first import |
| WalletConnect QR never shows | Missing project ID | App throws at startup — set `EXPO_PUBLIC_WC_PROJECT_ID` in `.env.local` |
| App crashes on Android | New Architecture mismatch | Rebuild dev client after changing `newArchEnabled` |
| "Contract not found at address" | Script uses a hardcoded address | Use FCL aliases (`0xFungibleToken`) configured in `fcl-config.ts` |
| Env var changes not picked up | Metro caches env vars | Restart `expo start` completely (kill the process) |
| Deep links don't return to app | Scheme not registered | Check `scheme` in `app.json` matches WC redirect |
| EAS Build fails on plugin | Missing `expo-build-properties` | It's in `package.json` — run `npm install` |

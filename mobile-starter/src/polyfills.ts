// Polyfills — this file MUST be the very first import in index.js / App.tsx.
//
// Expo SDK 52 enables inlineRequires by default, which means module-level
// assignments can execute before your imports if polyfills are scattered.
// Centralising them here and importing this file first guarantees correct order.

// 1. WalletConnect shims (events, URL, TextEncoder, etc.)
import '@walletconnect/react-native-compat'

// 2. Crypto entropy — must come after WC compat, before FCL
import 'react-native-get-random-values'

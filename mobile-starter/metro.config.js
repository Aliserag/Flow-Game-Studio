const { getDefaultConfig } = require('expo/metro-config')

const config = getDefaultConfig(__dirname)

// Required polyfills for @onflow/fcl-react-native + WalletConnect v2.
// These map Node.js built-ins that Metro cannot resolve natively.
config.resolver.extraNodeModules = {
  // Stub out Node built-ins unused in React Native
  // NOTE: do NOT stub 'url' — FCL uses it internally for endpoint parsing.
  // React Native provides a global URL and @walletconnect/react-native-compat
  // shims it; stubbing to empty-module breaks FCL's access node calls.
  assert: require.resolve('empty-module'),
  http:   require.resolve('empty-module'),
  https:  require.resolve('empty-module'),
  os:     require.resolve('empty-module'),
  zlib:   require.resolve('empty-module'),
  path:   require.resolve('empty-module'),
  // Map crypto and stream to browser-compatible implementations
  crypto: require.resolve('crypto-browserify'),
  stream: require.resolve('readable-stream'),
  buffer: require.resolve('buffer'),
}

// inlineRequires is enabled by default in Expo SDK 52. Do NOT override
// config.transformer.getTransformOptions here — Expo's getDefaultConfig
// manages transform options internally, and mutating it conflicts with
// the SDK's own config pipeline. Polyfill ordering is handled by
// polyfills.ts imported first in App.tsx.

module.exports = config

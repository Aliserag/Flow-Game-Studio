/// fcl-config.ts — Configure FCL for local emulator development.
///
/// For testnet/mainnet, replace accessNode.api and discovery.wallet,
/// and update the contract address aliases.
import * as fcl from "@onflow/fcl"

fcl.config({
  "app.detail.title": "Coin Flip on Flow",
  "app.detail.icon": "",
  // Local Flow emulator REST API
  "accessNode.api": "http://localhost:8888",
  // Local dev-wallet (flow dev-wallet or fcl-dev-wallet)
  "discovery.wallet": "http://localhost:8701/fcl/authn",
  "flow.network": "emulator",
  // Contract address aliases — match flow.json emulator-account
  "0xCoinFlip": "0xf8d6e0586b0a20c7",
  "0xRandomBeaconHistory": "0xf8d6e0586b0a20c7",
})

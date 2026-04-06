// fcl-config.ts — FCL configuration for NFT Battler.
// Targets the local Flow emulator by default.
// Swap accessNode.api and discovery.wallet for testnet/mainnet when deploying.

import * as fcl from "@onflow/fcl"

fcl.config({
  "app.detail.title": "NFT Battler on Flow",
  "app.detail.icon": "https://nft-battler.example/icon.png",
  "accessNode.api": "http://localhost:8888",
  "discovery.wallet": "http://localhost:8701/fcl/authn",
  "flow.network": "emulator",
  // Contract address aliases — all deployed to emulator-account for local dev
  "0xFighter": "0xf8d6e0586b0a20c7",
  "0xPowerUp": "0xf8d6e0586b0a20c7",
  "0xBattleArena": "0xf8d6e0586b0a20c7",
  "0xNonFungibleToken": "0xf8d6e0586b0a20c7",
  "0xMetadataViews": "0xf8d6e0586b0a20c7",
  "0xViewResolver": "0xf8d6e0586b0a20c7",
  "0xFungibleToken": "0xee82856bf20e2aa6",
})

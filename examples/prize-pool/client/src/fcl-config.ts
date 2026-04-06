/// fcl-config.ts — FCL configuration for the Prize Pool client.
/// Targets the local Flow emulator. Update addresses after deploying contracts.

import * as fcl from "@onflow/fcl"

fcl.config({
  "app.detail.title": "Prize Pool on Flow",
  "app.detail.icon": "https://prize-pool.example/icon.png",
  "accessNode.api": "http://localhost:8888",
  "discovery.wallet": "http://localhost:8701/fcl/authn",
  "flow.network": "emulator",

  // Contract addresses — update after running `flow project deploy`
  "0xWinnerTrophy": "0xf8d6e0586b0a20c7",
  "0xPrizePoolOrchestrator": "0xf8d6e0586b0a20c7",
  "0xNonFungibleToken": "0xf8d6e0586b0a20c7",
  "0xMetadataViews": "0xf8d6e0586b0a20c7",
  "0xViewResolver": "0xf8d6e0586b0a20c7",
  "0xRandomBeaconHistory": "0xf8d6e0586b0a20c7",
})

export { fcl }

export { VRFClient } from "./vrf.js";
export { NFTClient } from "./nft.js";
export { TokenClient } from "./token.js";
export { MarketplaceClient } from "./marketplace.js";
export { CONTRACT_ADDRESSES, ACCESS_NODES } from "./network-config.js";
export type { FlowNetwork, ContractAddresses } from "./network-config.js";

// SDK factory — configure once, use everywhere
import * as fcl from "@onflow/fcl";
import { FlowNetwork, ACCESS_NODES } from "./network-config.js";
import { VRFClient } from "./vrf.js";
import { NFTClient } from "./nft.js";
import { TokenClient } from "./token.js";
import { MarketplaceClient } from "./marketplace.js";

export function createFlowGameSDK(network: FlowNetwork) {
  fcl.config()
    .put("accessNode.api", ACCESS_NODES[network])
    .put("flow.network", network === "emulator" ? "local" : network);

  return {
    network,
    vrf: new VRFClient(network),
    nft: new NFTClient(network),
    token: new TokenClient(network),
    marketplace: new MarketplaceClient(network),
  };
}

// network-config.ts
// Contract addresses per network. Update after each deploy.
// Import this in all SDK modules — never hardcode addresses.

export type FlowNetwork = "emulator" | "testnet" | "mainnet";

export interface ContractAddresses {
  GameNFT: string;
  GameToken: string;
  GameAsset: string;
  RandomVRF: string;
  Scheduler: string;
  Marketplace: string;
  Tournament: string;
  StakingPool: string;
  Governance: string;
  SeasonPass: string;
  DynamicPricing: string;
  EmergencyPause: string;
  VersionRegistry: string;
  // EVM contracts
  FlowEVMVRF: string;      // EVM address (0x...)
  ZKVerifier: string;       // EVM address (0x...)
  EVMSafe: string;          // EVM address (0x...)
  // Standards
  NonFungibleToken: string;
  FungibleToken: string;
  MetadataViews: string;
  RandomBeaconHistory: string;
}

export const CONTRACT_ADDRESSES: Record<FlowNetwork, ContractAddresses> = {
  emulator: {
    GameNFT: "0xf8d6e0586b0a20c7",
    GameToken: "0xf8d6e0586b0a20c7",
    GameAsset: "0xf8d6e0586b0a20c7",
    RandomVRF: "0xf8d6e0586b0a20c7",
    Scheduler: "0xf8d6e0586b0a20c7",
    Marketplace: "0xf8d6e0586b0a20c7",
    Tournament: "0xf8d6e0586b0a20c7",
    StakingPool: "0xf8d6e0586b0a20c7",
    Governance: "0xf8d6e0586b0a20c7",
    SeasonPass: "0xf8d6e0586b0a20c7",
    DynamicPricing: "0xf8d6e0586b0a20c7",
    EmergencyPause: "0xf8d6e0586b0a20c7",
    VersionRegistry: "0xf8d6e0586b0a20c7",
    FlowEVMVRF: "0x0000000000000000000000000000000000000000",
    ZKVerifier: "0x0000000000000000000000000000000000000000",
    EVMSafe: "0x0000000000000000000000000000000000000000",
    NonFungibleToken: "0xf8d6e0586b0a20c7",
    FungibleToken: "0xf8d6e0586b0a20c7",
    MetadataViews: "0xf8d6e0586b0a20c7",
    RandomBeaconHistory: "0xf8d6e0586b0a20c7",
  },
  testnet: {
    // REPLACE after testnet deploy
    GameNFT: "REPLACE_AFTER_TESTNET_DEPLOY",
    GameToken: "REPLACE_AFTER_TESTNET_DEPLOY",
    GameAsset: "REPLACE_AFTER_TESTNET_DEPLOY",
    RandomVRF: "REPLACE_AFTER_TESTNET_DEPLOY",
    Scheduler: "REPLACE_AFTER_TESTNET_DEPLOY",
    Marketplace: "REPLACE_AFTER_TESTNET_DEPLOY",
    Tournament: "REPLACE_AFTER_TESTNET_DEPLOY",
    StakingPool: "REPLACE_AFTER_TESTNET_DEPLOY",
    Governance: "REPLACE_AFTER_TESTNET_DEPLOY",
    SeasonPass: "REPLACE_AFTER_TESTNET_DEPLOY",
    DynamicPricing: "REPLACE_AFTER_TESTNET_DEPLOY",
    EmergencyPause: "REPLACE_AFTER_TESTNET_DEPLOY",
    VersionRegistry: "REPLACE_AFTER_TESTNET_DEPLOY",
    FlowEVMVRF: "REPLACE_AFTER_EVM_DEPLOY",
    ZKVerifier: "REPLACE_AFTER_EVM_DEPLOY",
    EVMSafe: "REPLACE_AFTER_EVM_DEPLOY",
    NonFungibleToken: "0x631e88ae7f1d7c20",
    FungibleToken: "0x9a0766d93b6608b7",
    MetadataViews: "0x631e88ae7f1d7c20",
    RandomBeaconHistory: "0x8c5303eaa26202d6",
  },
  mainnet: {
    // REPLACE after mainnet deploy
    GameNFT: "REPLACE_AFTER_MAINNET_DEPLOY",
    GameToken: "REPLACE_AFTER_MAINNET_DEPLOY",
    GameAsset: "REPLACE_AFTER_MAINNET_DEPLOY",
    RandomVRF: "REPLACE_AFTER_MAINNET_DEPLOY",
    Scheduler: "REPLACE_AFTER_MAINNET_DEPLOY",
    Marketplace: "REPLACE_AFTER_MAINNET_DEPLOY",
    Tournament: "REPLACE_AFTER_MAINNET_DEPLOY",
    StakingPool: "REPLACE_AFTER_MAINNET_DEPLOY",
    Governance: "REPLACE_AFTER_MAINNET_DEPLOY",
    SeasonPass: "REPLACE_AFTER_MAINNET_DEPLOY",
    DynamicPricing: "REPLACE_AFTER_MAINNET_DEPLOY",
    EmergencyPause: "REPLACE_AFTER_MAINNET_DEPLOY",
    VersionRegistry: "REPLACE_AFTER_MAINNET_DEPLOY",
    FlowEVMVRF: "REPLACE_AFTER_EVM_DEPLOY",
    ZKVerifier: "REPLACE_AFTER_EVM_DEPLOY",
    EVMSafe: "REPLACE_AFTER_EVM_DEPLOY",
    NonFungibleToken: "0x1d7e57aa55817448",
    FungibleToken: "0xf233dcee88fe0abe",
    MetadataViews: "0x1d7e57aa55817448",
    RandomBeaconHistory: "0xd7431fd358660d73",
  },
};

export const ACCESS_NODES: Record<FlowNetwork, string> = {
  emulator: "http://localhost:8888",
  testnet: "https://rest-testnet.onflow.org",
  mainnet: "https://rest-mainnet.onflow.org",
};

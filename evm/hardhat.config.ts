import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";

// Flow EVM network config
// Chain IDs: testnet=545, mainnet=747
// Verify current RPC endpoints at: https://developers.flow.com/evm/networks

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  networks: {
    "flow-testnet": {
      url: "https://testnet.evm.nodes.onflow.org",
      chainId: 545,
      accounts: process.env.EVM_PRIVATE_KEY ? [process.env.EVM_PRIVATE_KEY] : [],
    },
    "flow-mainnet": {
      url: "https://mainnet.evm.nodes.onflow.org",
      chainId: 747,
      accounts: process.env.EVM_PRIVATE_KEY ? [process.env.EVM_PRIVATE_KEY] : [],
    },
    "flow-emulator": {
      url: "http://localhost:8545",  // Flow emulator EVM port
      chainId: 1337,
      accounts: ["0xf8d6e0586b0a20c7f8d6e0586b0a20c7f8d6e0586b0a20c7f8d6e0586b0a20c7"],
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;

import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  networks: {
    "flow-emulator": {
      url: "http://localhost:8545",
      chainId: 1337,
      accounts: ["0x2eae2f31cb5b756151fa11d82949763b73e28b92f8cc26c97d5bf4620e60d8b6"],
    },
  },
}

export default config

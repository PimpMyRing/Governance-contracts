import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    // Add a local development network
    testnet: {
      url: "", // Your local Ethereum node URL
    },
    // Add more networks here if needed
  },
};

export default config;

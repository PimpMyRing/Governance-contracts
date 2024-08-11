import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  etherscan: {
    apiKey: {
      optimismSepolia: process.env.OP_ETHERSCAN_API_KEY || '',
      optimism: process.env.OP_ETHERSCAN_API_KEY || '',
      baseMainnet: process.env.BASE_ETHERSCAN_API_KEY || '',
    },
    customChains: [
      {
        network: "optimismSepolia",
        chainId: 11155420,
        urls: {
          apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io/"
        }
      },
      {
        network: "optimism",
        chainId: 10,
        urls: {
          apiURL: "https://api-optimistic.etherscan.io/api",
          browserURL: "https://optimistic.etherscan.io/"
        }
      },
      {
        network: "baseMainnet",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org/"
        }
      },
    ]
  },
  
  networks: {
    // Optimism
    optimism: {
      url: "https://mainnet.optimism.io",
      accounts: [process.env.PRIVATE_KEY || ''],
    },
    optimismSepolia: {
      url: "https://sepolia.optimism.io",
      accounts: [process.env.PRIVATE_KEY || ''],
    },
    // Base Testnet
    baseTestnet: {
      url: "https://goerli.base.org",
      accounts: [process.env.PRIVATE_KEY || ''],
    },
    // Base Mainnet
    baseMainnet: {
      url: "https://mainnet.base.org",
      accounts: [process.env.PRIVATE_KEY || ''],
    },

  },
  
};

export default config;

//npx hardhat run scripts/deploy_SBT.ts --network optimismSepolia
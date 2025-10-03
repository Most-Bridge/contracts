require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */

module.exports = {
  paths: {
    sources: "./src",
  },

  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    opSepolia: {
      url: process.env.OP_SEPOLIA_RPC || "",
      accounts: [process.env.DEPLOY_PRIVATE_KEY],
    },
    ethSepolia: {
      url: process.env.ETH_SEPOLIA_RPC || "",
      accounts: [process.env.DEPLOY_PRIVATE_KEY],
    },
    worldchainTestnet: {
      url: process.env.WLD_SEPOLIA_RPC || "",
      accounts: [process.env.DEPLOY_PRIVATE_KEY],
    },
    worldchain: {
      url: process.env.WLD_MAINNET_RPC || "",
      accounts: [process.env.DEPLOY_PRIVATE_KEY],
    },
    optimism: {
      url: process.env.OPTIMISM_RPC || "",
      accounts: [process.env.DEPLOY_PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.ETH_TEST_ETHERSCAN_API_KEY,
    customChains: [
      {
        network: "worldchain",
        chainId: 480,
        urls: {
          apiURL: "https://api.worldscan.org",
          browserURL: "https://worldscan.org",
        },
      },
      {
        network: "opSepolia",
        chainId: 11155420,
        urls: {
          apiURL: "https://api.sepolia-optimism.etherscan.io",
          browserURL: "https://sepolia-optimism.etherscan.io",
        },
      },
      {
        network: "optimism",
        chainId: 10,
        urls: {
          apiURL: "https://api.optimistic.etherscan.io/",
          browserURL: "https://optimistic.etherscan.io/",
        },
      },
    ],
  },
};

require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */

console.log(process.env.ETH_TEST_ETHERSCAN_API_KEY, "ETH_TEST_ETHERSCAN_API_KEY");
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
  },
  etherscan: {
    apiKey: {
      optimisticSepolia: process.env.OP_ETHERSCAN_API_KEY,
      sepolia: process.env.ETH_TEST_ETHERSCAN_API_KEY,
      worldchainTestnet: process.env.ETH_TEST_ETHERSCAN_API_KEY,
    },
  },
};

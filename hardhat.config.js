require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  // Add this paths object to point to your 'src' folder
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
    },
  },
  networks: {
    opSepolia: {
      url: process.env.OP_SEPOLIA_RPC || "",
      accounts: [process.env.DEPLOY_PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      optimisticSepolia: process.env.OP_ETHERSCAN_API_KEY,
    },
  },
};

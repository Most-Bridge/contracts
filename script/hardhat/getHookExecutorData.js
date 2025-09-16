const hre = require("hardhat");
const { ethers, artifacts } = hre;

async function main() {
  // Read HookExecutor artifact
  const artifact = await artifacts.readArtifact("HookExecutor");

  // This is the CREATION code (the one CREATE2 cares about)
  const creationCode = artifact.bytecode;
  console.log("HookExecutor creation code:", creationCode);

  // If you want the hash directly:
  const creationCodeHash = ethers.utils.keccak256(creationCode);
  console.log("HookExecutor creation code hash:", creationCodeHash);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

// To run this script, use the following command:
// npx hardhat run script/hardhat/getHookExecutorData.js

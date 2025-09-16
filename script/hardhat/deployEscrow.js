const hre = require("hardhat");

/**
 * A helper function to manually pad a hex string to a bytes32 value.
 * @param {string | number} value - The value to pad.
 * @returns {string} The padded bytes32 hex string.
 */
function toPaddedBytes32(value) {
  // Convert number to hex string if necessary
  let hex = typeof value === 'number' ? value.toString(16) : value;

  // Remove '0x' prefix if it exists
  if (hex.startsWith('0x')) {
    hex = hex.slice(2);
  }

  // Pad the string with leading zeros to 64 characters (32 bytes)
  const paddedHex = hex.padStart(64, '0');

  return `0x${paddedHex}`;
}

async function main() {
  console.log("Preparing constructor arguments...");

  const initialHDPChainConnections = [
    {
      destinationChainId: toPaddedBytes32(11155420),
      paymentRegistryAddress: toPaddedBytes32("0x9eB3feB35884B284Ea1e38Dd175417cE90B43AA1"),
      hdpProgramHash: "0x07ae890076e0f39de9dd1761f8261b20fca3169b404b75284f9ceae0864736d5",
    },
    {
      destinationChainId: "0x534e5f5345504f4c494100000000000000000000000000000000000000000000",
      paymentRegistryAddress: "0x0740aa1758532dd9cb945a52a59d949aed280733fb243b7721666a1aa1989d55",
      hdpProgramHash: "0x0228737596cc16de4a733aec478701996f6c0f937fe66144781d91537b6df629",
    },
  ];

  console.log("Deploying Escrow contract...");

  const Escrow = await hre.ethers.getContractFactory("Escrow");
  const escrow = await Escrow.deploy(initialHDPChainConnections);

  await escrow.waitForDeployment();

  const contractAddress = await escrow.getAddress();
  console.log(`✅ Escrow contract deployed to: ${contractAddress}`);
  console.log("Waiting for block confirmations before verification...");

  // Wait for 5 block confirmations
  await escrow.deploymentTransaction().wait(5);

  console.log("Verifying contract on Etherscan...");
  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: [initialHDPChainConnections],
    });
    console.log("✅ Contract verified successfully!");
  } catch (e) {
    if (e.message.toLowerCase().includes("already verified")) {
      console.log("Contract is already verified.");
    } else {
      console.error("Verification failed:", e);
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// To run this script, use the following command:
// npx hardhat run script/hardhat/deployEscrow.js --network worldchain

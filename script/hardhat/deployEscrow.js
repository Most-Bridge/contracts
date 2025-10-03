const hre = require("hardhat");

/**
 * A helper function to manually pad a hex string to a bytes32 value.
 * @param {string | number} value - The value to pad.
 * @returns {string} The padded bytes32 hex string.
 */
function toPaddedBytes32(value) {
  // Convert number to hex string if necessary
  let hex = typeof value === "number" ? value.toString(16) : value;

  // Remove '0x' prefix if it exists
  if (hex.startsWith("0x")) {
    hex = hex.slice(2);
  }

  // Pad the string with leading zeros to 64 characters (32 bytes)
  const paddedHex = hex.padStart(64, "0");

  return `0x${paddedHex}`;
}

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForConfirmations(provider, txHash, confirmations, intervalMs) {
  let receipt = null;
  while (receipt === null) {
    try {
      receipt = await provider.getTransactionReceipt(txHash);
    } catch (e) {
      await sleep(intervalMs);
      continue;
    }
    if (receipt === null) {
      await sleep(intervalMs);
    }
  }

  const txBlock = receipt.blockNumber;
  for (;;) {
    let currentBlock;
    try {
      currentBlock = await provider.getBlockNumber();
    } catch (e) {
      await sleep(intervalMs);
      continue;
    }

    const confs = currentBlock - txBlock + 1;
    if (confs >= confirmations) {
      break;
    }
    await sleep(intervalMs);
  }
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
    {
      destinationChainId: toPaddedBytes32(10),
      paymentRegistryAddress: toPaddedBytes32("0x68F2b1C86B58A98D1F5c494393FF9e5A588c2ed1"),
      hdpProgramHash: toPaddedBytes32("0xa66784d2cbc0987f320e5a19f83e2fa2a0c9f1a921505684f1f2d954af99f3"),
    },
  ];

  console.log("Deploying Escrow contract...");

  const Escrow = await hre.ethers.getContractFactory("Escrow");
  const escrow = await Escrow.deploy(initialHDPChainConnections);

  await escrow.waitForDeployment();

  const contractAddress = await escrow.getAddress();
  console.log(`✅ Escrow contract deployed to: ${contractAddress}`);
  console.log("Waiting for block confirmations before verification...");

  const confirmations = Number(process.env.CONFIRMATIONS || 5);
  const pollIntervalMs = Number(process.env.CONFIRMATION_POLL_INTERVAL_MS || 15000);
  const txHash = escrow.deploymentTransaction().hash;
  await waitForConfirmations(hre.ethers.provider, txHash, confirmations, pollIntervalMs);

  console.log("Verifying contract on Etherscan...");
  try {
    const maxAttempts = Number(process.env.VERIFY_MAX_ATTEMPTS || 5);
    const baseDelayMs = Number(process.env.VERIFY_RETRY_BASE_DELAY_MS || 10000);
    let attempt = 0;
    for (;;) {
      attempt += 1;
      try {
        await hre.run("verify:verify", {
          address: contractAddress,
          constructorArguments: [initialHDPChainConnections],
        });
        console.log("✅ Contract verified successfully!");
        break;
      } catch (err) {
        const message = (err && err.message ? err.message : "").toLowerCase();
        if (message.includes("already verified")) {
          console.log("Contract is already verified.");
          break;
        }
        const isRateLimited = message.includes("too many requests") || message.includes("429");
        if (attempt < maxAttempts && isRateLimited) {
          const delay = baseDelayMs * attempt;
          console.log(
            `Verification rate-limited (attempt ${attempt}/${maxAttempts}). Retrying in ${Math.round(delay / 1000)}s...`
          );
          await sleep(delay);
          continue;
        }
        throw err;
      }
    }
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

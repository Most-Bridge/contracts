const hre = require("hardhat");

async function main() {
  console.log("Deploying PaymentRegistry contract...");

  const PaymentRegistry = await hre.ethers.getContractFactory("PaymentRegistry");
  const paymentRegistry = await PaymentRegistry.deploy();

  await paymentRegistry.waitForDeployment();

  const contractAddress = await paymentRegistry.getAddress();
  console.log(`✅ PaymentRegistry contract deployed to: ${contractAddress}`);
  console.log("Waiting for block confirmations before verification...");

  // Wait for 5 block confirmations
  await paymentRegistry.deploymentTransaction().wait(5);

  console.log("Verifying contract on Etherscan...");
  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: [], // none for payment registry
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
// npx hardhat run script/hardhat/deployPaymentRegistry.js --network opSepolia

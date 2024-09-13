import { ethers } from "hardhat";

import type { EncryptedFunds } from "../../types";
import { getSigners } from "../signers";

// Deploy the EncryptedFunds contract
export async function deployEncryptedFundsFixture(): Promise<EncryptedFunds> {
  const signers = await getSigners(); // Fetch signers

  // Get the contract factory for the EncryptedFunds contract
  const contractFactory = await ethers.getContractFactory("EncryptedFunds");

  // Connect to Alice's signer for deployment
  const contract = await contractFactory.connect(signers.alice).deploy(); // Deploy without constructor arguments

  // Ensure contract is fully deployed before returning it
  await contract.waitForDeployment();

  return contract; // Return the deployed contract instance
}

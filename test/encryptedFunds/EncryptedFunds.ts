import { expect } from "chai";
import { ethers } from "hardhat";

import { createInstances, decrypt64 } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deployEncryptedFundsFixture } from "./EncryptedFunds.fixture";

// Assuming you have these encryption utilities

describe("EncryptedFunds", function () {
  before(async function () {
    await initSigners(); // Initialize the signers
    this.signers = await getSigners(); // Fetch Alice, Bob, and others
  });

  beforeEach(async function () {
    // Deploy the contract before each test
    this.contract = await deployEncryptedFundsFixture();
    this.erc20 = this.contract;
    this.contractAddress = await this.contract.getAddress();
    this.instances = await createInstances(this.signers); // Set up encryption instances for Alice and Bob
  });

  it("should transfer Token A from Alice to Bob with encrypted zero token ID", async function () {
    // Fetch encrypted token ID for Token A using the getter function
    const tokenAID = await this.contract.getEncryptedTokenID(0); // Token A ID
    console.log(tokenAID);

    // Fetch encrypted token ID for Token B using the getter function
    const tokenBID = await this.contract.getEncryptedTokenID(1); // Token B ID
    console.log(tokenBID);

    // Mint 1,000,000 tokens of Token A to Alice
    const mintTxA = await this.contract.mint(tokenAID, 1000000);
    await mintTxA.wait();

    // Mint 1,000,000 tokens of Token B to Bob
    const mintTxB = await this.contract.mint(tokenBID, 1000000);
    await mintTxB.wait();

    // The following is a very weird work around to get an encrypted value of 1 and to
    // use that as the tokenAID encrypted value that is passed through to the transferFrom function
    const bal = await this.contract.totalSupply(tokenBID);
    console.log(bal);

    // burning 999,999 of token B to get supply of 1
    const burntx = await this.contract.burn(tokenBID, 999999);
    await burntx.wait();
    // 'one' will be passed in to transferFrom function call to illustrate how tokenAID is never revealed
    const one = await this.contract.totalSupply(tokenBID);
    console.log(one);

    // const onedec = await decrypt64(one);
    // console.log(onedec);
    // const tokenAIDdec = await decrypt64(tokenAID);
    // console.log(tokenAIDdec);

    // const balanceHandleAlice = await this.contract.balanceOf(this.signers.alice.address, tokenAID); // Use actual stored Token A ID for comparison
    // const balanceAliceDecrypted1 = await decrypt64(balanceHandleAlice); // Decrypt Alice's balance
    // console.log(balanceAliceDecrypted1);

    // Encryption setup for the transfer amount
    const input = this.instances.alice.createEncryptedInput(this.contractAddress, this.signers.alice.address);
    input.add64(1337); // Add the transfer amount (1337)
    const encryptedTransferAmount = input.encrypt(); // Encrypt the transfer amount

    // Transfer 1337 Token A from Alice to Bob, passing the encrypted zero value for token ID
    // Call transferFrom directly with the necessary parameters
    // Call transferFrom directly with the necessary parameters
    const tx = await this.contract.connect(this.signers.alice).transferFrom(
      this.signers.alice.address, // From address (Alice)
      this.signers.bob.address, // To address (Bob)
      tokenAID, // Encrypted Token ID (using the actual tokenAID value for now to get it working); will substitute with 'one' after
      encryptedTransferAmount.handles[0], // Encrypted transfer amount
      encryptedTransferAmount.inputProof, // Input proof
    );

    // Wait for the transaction to complete
    await tx.wait();

    // Verify Alice's new balance (decrypt it)
    const balanceHandleAlice1 = await this.contract.balanceOf(this.signers.alice.address, tokenAID); // Use actual stored Token A ID for comparison
    const balanceAliceDecrypted = await decrypt64(balanceHandleAlice1); // Decrypt Alice's balance

    expect(balanceAliceDecrypted).to.equal(1000000 - 1337); // Alice should have 1000000 - 1337

    // Verify Bob's new balance (decrypt it)
    const balanceHandleBob = await this.contract.balanceOf(this.signers.bob.address, tokenAID); // Use actual stored Token A ID for comparison
    const balanceBobDecrypted = await decrypt64(balanceHandleBob); // Decrypt Bob's balance

    expect(balanceBobDecrypted).to.equal(1337); // Bob should have 1337 Token A
  });
});

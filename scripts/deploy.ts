import { ethers } from "hardhat";

async function main() {
  // Define the campaign duration (in seconds) and the goal (in Ether)
  const campaignDurationInSeconds = 30 * 24 * 60 * 60; // 30 days
  const campaignGoalInEther = 100; // 100 Ether

  // Parse the goal to wei
  const campaignGoalInWei = ethers.utils.parseEther(
    campaignGoalInEther.toString()
  );

  // Get the contract factory
  const Kickstarter = await ethers.getContractFactory("Kickstarter");

  // Deploy the contract
  const kickstarter = await Kickstarter.deploy(
    campaignDurationInSeconds,
    campaignGoalInWei
  );

  // Wait for the transaction to be mined
  await kickstarter.deployed();

  console.log(
    "Kickstarter campaign deployed to:",
    kickstarter.address
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

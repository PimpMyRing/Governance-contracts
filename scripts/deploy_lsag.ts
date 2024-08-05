import { ethers } from "hardhat";

async function main() {
  // Replace 'LSAGVerifier' with the name of your contract
  const LSAGVerifier = await ethers.deployContract("LSAGVerifier");
  const lsagVerifier = await LSAGVerifier.waitForDeployment();


  console.log("LSAGVerifier deployed to:", lsagVerifier.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
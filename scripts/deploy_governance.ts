import { ethers } from "hardhat";

async function main() {
  // Replace 'LSAGVerifier' with the name of your contract
  const Governance = await ethers.deployContract("DAOofTheRing");
  const gov = await Governance.waitForDeployment();


  console.log("DAOofTheRing deployed to:", gov.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
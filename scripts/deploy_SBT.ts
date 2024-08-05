import { ethers } from "hardhat";

async function main() {
  // Replace 'LSAGVerifier' with the name of your contract
  const SBT = await ethers.deployContract("DaoMemberShip");
  const sbt = await SBT.waitForDeployment();


  console.log("DaoMemberShip deployed to:", sbt.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
import { ethers } from "hardhat";

async function main() {
  // Deploy the LSAGVerifier library
  const LSAGVerifier = await ethers.getContractFactory("LSAGVerifier");
  const lsagVerifier = await LSAGVerifier.deploy();

  console.log("LSAGVerifier deployed to:", lsagVerifier.target);

  // Link the LSAGVerifier library to the DAOofTheRing contract
  const GovernanceFactory = await ethers.getContractFactory("DAOofTheRing", {
    libraries: {
      LSAGVerifier: lsagVerifier.target,
    },
  });

  const governance = await GovernanceFactory.deploy();

  console.log("DAOofTheRing deployed to:", governance.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
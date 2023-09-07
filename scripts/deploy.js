const hre = require('hardhat')
const { ethers, upgrades } = require('hardhat');

async function main() {
    const deployer = await hre.ethers.getSigner();

    const Firewall = await hre.ethers.getContractFactory("Firewall", deployer);
    const SampleConsumer = await hre.ethers.getContractFactory("SampleConsumer", deployer);
    const AdminCallPolicy = await hre.ethers.getContractFactory("AdminCallPolicy", deployer);

    const firewall = await upgrades.deployProxy(Firewall, []);
    await firewall.deployed();
    const adminCallPolicy = await AdminCallPolicy.deploy();
    await adminCallPolicy.deployed();
    const sampleConsumer = await SampleConsumer.deploy(firewall.address);
    await sampleConsumer.deployed();

    console.log("Firewall deployed to:", firewall.address);
    console.log("AdminCallPolicy deployed to:", adminCallPolicy.address);
    console.log("SampleConsumer deployed to:", sampleConsumer.address);

    await firewall.setPolicyStatus(adminCallPolicy.address, true);
    await firewall.addPolicy(
        sampleConsumer.address,
        SampleConsumer.interface.getSighash('setOwner(address)'),
        adminCallPolicy.address
    );
    console.log("Done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

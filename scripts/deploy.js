const hre = require('hardhat')

async function main() {
    const deployer = await hre.ethers.getSigner();

    const Firewall = await hre.ethers.getContractFactory("Firewall", deployer);
    const SampleConsumer = await hre.ethers.getContractFactory("SampleConsumer", deployer);
    const ApprovedCallsWithSignaturePolicy = await hre.ethers.getContractFactory("ApprovedCallsWithSignaturePolicy", deployer);

    const firewall = await Firewall.deploy();
    await firewall.deployed();
    const approvedCallsWithSignaturePolicy = await ApprovedCallsWithSignaturePolicy.deploy();
    await approvedCallsWithSignaturePolicy.deployed();
    const sampleConsumer = await SampleConsumer.deploy(firewall.address);
    await sampleConsumer.deployed();

    await approvedCallsWithSignaturePolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('SIGNER_ROLE')), deployer.address);

    console.log("Firewall deployed to:", firewall.address);
    console.log("ApprovedCallsWithSignaturePolicy deployed to:", approvedCallsWithSignaturePolicy.address);
    console.log("SampleConsumer deployed to:", sampleConsumer.address);

    await firewall.setPolicyStatus(approvedCallsWithSignaturePolicy.address, true);
    await firewall.addGlobalPolicy(
        sampleConsumer.address,
        approvedCallsWithSignaturePolicy.address
    );
    console.log("Done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

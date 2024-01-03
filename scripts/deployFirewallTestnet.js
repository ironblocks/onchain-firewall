const hre = require('hardhat')

async function main() {
    const deployer = await hre.ethers.getSigner();

    const Firewall = await hre.ethers.getContractFactory("Firewall", deployer);
    const SampleConsumer = await hre.ethers.getContractFactory("SampleConsumer", deployer);

    const firewall = await Firewall.deploy();
    // const firewall = await Firewall.attach('0x549Cdd962502111b7C28Fc43CC6BD27De0AD36B8');
    await firewall.deployed();
    console.log("Firewall deployed to:", firewall.address);
    const sampleConsumer = await SampleConsumer.deploy(firewall.address);
    // const sampleConsumer = await SampleConsumer.attach('0xf2F621f44199f8cA6668a0823A939EA832Ce6a4d');
    await sampleConsumer.deployed();
    console.log("SampleConsumer deployed to:", sampleConsumer.address);

    const AdminCallPolicy = await hre.ethers.getContractFactory("AdminCallPolicy", deployer);
    const adminCallPolicy = await AdminCallPolicy.deploy();
    await adminCallPolicy.deployed();
    await (await firewall.setPolicyStatus(adminCallPolicy.address, true)).wait();
    console.log("AdminCallPolicy deployed to:", adminCallPolicy.address);

    const AllowlistPolicy = await hre.ethers.getContractFactory("AllowlistPolicy", deployer);
    const allowlistPolicy = await AllowlistPolicy.deploy();
    await allowlistPolicy.deployed();
    await (await firewall.setPolicyStatus(allowlistPolicy.address, true)).wait();
    console.log("AllowlistPolicy deployed to:", allowlistPolicy.address);

    const ApprovedCallsWithSignaturePolicy = await hre.ethers.getContractFactory("ApprovedCallsWithSignaturePolicy", deployer);
    const approvedCallsWithSignaturePolicy = await ApprovedCallsWithSignaturePolicy.deploy();
    await approvedCallsWithSignaturePolicy.deployed();
    await (await approvedCallsWithSignaturePolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('SIGNER_ROLE')), deployer.address)).wait();
    await (await firewall.setPolicyStatus(approvedCallsWithSignaturePolicy.address, true)).wait();
    console.log("ApprovedCallsWithSignaturePolicy deployed to:", approvedCallsWithSignaturePolicy.address);

    const ApprovedVectorsPolicy = await hre.ethers.getContractFactory("ApprovedVectorsPolicy", deployer);
    const approvedVectorsPolicy = await ApprovedVectorsPolicy.deploy();
    await approvedVectorsPolicy.deployed();
    await (await firewall.setPolicyStatus(approvedVectorsPolicy.address, true)).wait();
    console.log("ApprovedVectorsPolicy deployed to:", approvedVectorsPolicy.address);

    const CombinedPoliciesPolicy = await hre.ethers.getContractFactory("CombinedPoliciesPolicy", deployer);
    const combinedPoliciesPolicy = await CombinedPoliciesPolicy.deploy();
    await combinedPoliciesPolicy.deployed();
    await (await firewall.setPolicyStatus(combinedPoliciesPolicy.address, true)).wait();
    console.log("CombinedPoliciesPolicy deployed to:", combinedPoliciesPolicy.address);

    const ForbiddenMethodsPolicy = await hre.ethers.getContractFactory("ForbiddenMethodsPolicy", deployer);
    const forbiddenMethodsPolicy = await ForbiddenMethodsPolicy.deploy();
    await forbiddenMethodsPolicy.deployed();
    await (await firewall.setPolicyStatus(forbiddenMethodsPolicy.address, true)).wait();
    console.log("ForbiddenMethodsPolicy deployed to:", forbiddenMethodsPolicy.address);

    const NonReentrantPolicy = await hre.ethers.getContractFactory("NonReentrantPolicy", deployer);
    const nonReentrantPolicy = await NonReentrantPolicy.deploy();
    await nonReentrantPolicy.deployed();
    await (await firewall.setPolicyStatus(nonReentrantPolicy.address, true)).wait();
    console.log("NonReentrantPolicy deployed to:", nonReentrantPolicy.address);

    const BalanceChangePolicy = await hre.ethers.getContractFactory("BalanceChangePolicy", deployer);
    const balanceChangePolicy = await BalanceChangePolicy.deploy();
    await balanceChangePolicy.deployed();
    await (await firewall.setPolicyStatus(balanceChangePolicy.address, true)).wait();
    console.log("BalanceChangePolicy deployed to:", balanceChangePolicy.address);

    const OnlyEOAPolicy = await hre.ethers.getContractFactory("OnlyEOAPolicy", deployer);
    const onlyEOAPolicy = await OnlyEOAPolicy.deploy();
    await onlyEOAPolicy.deployed();
    await (await firewall.setPolicyStatus(onlyEOAPolicy.address, true)).wait();
    console.log("OnlyEOAPolicy deployed to:", onlyEOAPolicy.address);

    console.log("Done");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

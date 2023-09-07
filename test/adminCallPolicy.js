const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('Admin Call Policy', function () {
    let owner, addr1, addr2;
    let firewall, sampleConsumer, sampleConsumerIface;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        firewall = await upgrades.deployProxy(FirewallFactory, []);
        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
        sampleConsumerIface = SampleConsumerFactory.interface;
    });

    it('Firewall Admin call policy onlyOwner functions', async function () {
        const AdminCallPolicy = await ethers.getContractFactory(
            'AdminCallPolicy'
        );
        const adminCallPolicy =
            await AdminCallPolicy.deploy();
        await expect(
            adminCallPolicy.connect(addr1).approveCall(
                `0x${'00'.repeat(32)}`
            )
        ).to.be.revertedWith('Ownable: caller is not the owner');
        await expect(
            adminCallPolicy.connect(addr1).setExpirationTime(
                10000
            )
        ).to.be.revertedWith('Ownable: caller is not the owner');
        await expect(
            adminCallPolicy.connect(owner).setExpirationTime(
                10000
            )
        ).to.not.be.reverted;
    });

    it('Firewall Admin call policy approved/unapproved calls', async function () {
        const AdminCallPolicy = await ethers.getContractFactory(
            'AdminCallPolicy'
        );
        const adminCallPolicy =
            await AdminCallPolicy.deploy();

        await firewall.setPolicyStatus(adminCallPolicy.address, true);
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('setOwner(address)'),
            adminCallPolicy.address
        );
        await expect(
            sampleConsumer
                .connect(owner)
                .setOwner(addr1.address)
        ).to.be.revertedWith('AdminCallPolicy: Call not approved');
        const setOwnerPayload = sampleConsumerIface.encodeFunctionData(
            'setOwner(address)',
            [addr1.address]
        );
        const callHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                owner.address,
                owner.address,
                setOwnerPayload,
                0,
            ]
        );
        await adminCallPolicy.approveCall(callHash);
        await expect(
            sampleConsumer
                .connect(owner)
                .setOwner(addr1.address)
        ).to.not.be.reverted;
    });

});

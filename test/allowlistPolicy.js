const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Allowlist Policy', function () {
    let addr1, addr2;
    let firewall, sampleConsumer, sampleConsumerIface;

    beforeEach(async function () {
        [addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        firewall = await FirewallFactory.deploy();
        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
        sampleConsumerIface = SampleConsumerFactory.interface;
    });

    it('Firewall allowlist', async function () {
        const AllowlistPolicy = await ethers.getContractFactory(
            'AllowlistPolicy'
        );
        const allowlistPolicy = await AllowlistPolicy.deploy();
        await firewall.setPolicyStatus(allowlistPolicy.address, true);
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            allowlistPolicy.address
        );
        await expect(
            allowlistPolicy
                .connect(addr2)
                .setConsumerAllowlist(
                    sampleConsumer.address,
                    addr1.address,
                    true
                )
        ).to.be.revertedWith('Ownable: caller is not the owner');
        await allowlistPolicy.setConsumerAllowlist(
            sampleConsumer.address,
            addr1.address,
            true
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.be.revertedWith('AllowlistPolicy: Sender not allowed');
        await expect(
            sampleConsumer
                .connect(addr1)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

});

const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Private Invariant Policy', function () {
    let addr1, addr2;
    let firewall, sampleInvariantConsumer, sampleInvariantConsumerIface;
    let invariantPolicy, sampleInvariantLogic;

    beforeEach(async function () {
        [addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleInvariantConsumerFactory = await ethers.getContractFactory(
            'SampleInvariantConsumer'
        );
        const PrivateInvariantsPolicyFactory = await ethers.getContractFactory(
            'PrivateInvariantsPolicy'
        );
        const SampleInvariantLogicFactory = await ethers.getContractFactory(
            'SampleInvariantLogic'
        );
        firewall = await FirewallFactory.deploy();
        sampleInvariantConsumer = await SampleInvariantConsumerFactory.deploy(firewall.address);
        invariantPolicy = await PrivateInvariantsPolicyFactory.deploy();
        sampleInvariantLogic = await SampleInvariantLogicFactory.deploy();
        sampleInvariantConsumerIface = SampleInvariantConsumerFactory.interface;
        await firewall.setPolicyStatus(invariantPolicy.address, true);
        await invariantPolicy.setInvariantLogicContract(sampleInvariantLogic.address);
    });

    it('Basic invariants 1', async function () {
        await firewall.setPrivateInvariantsPolicy(
            sampleInvariantConsumer.address,
            [sampleInvariantConsumerIface.getSighash('setValue(uint256)')],
            [invariantPolicy.address]
        );
        await invariantPolicy.setSighashInvariantStorageSlots(
            sampleInvariantConsumer.address,
            sampleInvariantConsumerIface.getSighash('setValue(uint256)'),
            [ethers.utils.hexZeroPad('0x2', 32)]
        );
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setValue(
                    1
                )
        ).to.not.be.reverted;
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setValue(
                    0
                )
        ).to.be.revertedWith("INVARIANT1");
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setValue(
                    50
                )
        ).to.not.be.reverted;
    });

    it('Basic invariants 2', async function () {
        await firewall.setPrivateInvariantsPolicy(
            sampleInvariantConsumer.address,
            [sampleInvariantConsumerIface.getSighash('setMultipleValues(uint256,uint256)')],
            [invariantPolicy.address]
        );
        await invariantPolicy.setSighashInvariantStorageSlots(
            sampleInvariantConsumer.address,
            sampleInvariantConsumerIface.getSighash('setMultipleValues(uint256,uint256)'),
            [ethers.utils.hexZeroPad('0x3', 32), ethers.utils.hexZeroPad('0x4', 32)]
        );
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setMultipleValues(1, 1)
        ).to.not.be.reverted;
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setMultipleValues(1, 52)
        ).to.be.revertedWith("INVARIANT2");
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setMultipleValues(1, 51)
        ).to.not.be.reverted;
        await expect(
            sampleInvariantConsumer
                .connect(addr2)
                .setMultipleValues(1, 500)
        ).to.be.revertedWith("INVARIANT2");
    });

});

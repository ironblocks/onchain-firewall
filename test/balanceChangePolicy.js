const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('Balance Change Policy', function () {
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

    it('Firewall balance change', async function () {
        const BalanceChangePolicy = await ethers.getContractFactory(
            'BalanceChangePolicy'
        );
        const balanceChangePolicy = await BalanceChangePolicy.deploy();
        await firewall.setPolicyStatus(balanceChangePolicy.address, true);
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            balanceChangePolicy.address
        );
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('withdraw(uint256)'),
            balanceChangePolicy.address
        );
        await expect(
            balanceChangePolicy.connect(addr1).setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ethers.utils.parseEther('25')
        )
        ).to.be.revertedWith('Ownable: caller is not the owner');
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ethers.utils.parseEther('25')
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('25.000001') })
        ).to.be.revertedWith(
            'BalanceChangePolicy: Balance change exceeds limit'
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('25') })
        ).to.not.be.reverted;
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
        await expect(
            sampleConsumer
                .connect(addr2)
                .withdraw(ethers.utils.parseEther('25.0000001'))
        ).to.be.revertedWith(
            'BalanceChangePolicy: Balance change exceeds limit'
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .withdraw(ethers.utils.parseEther('25'))
        ).to.not.be.reverted;
    });
});

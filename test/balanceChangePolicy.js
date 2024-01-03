const { expect } = require('chai');
const { ethers } = require('hardhat');

const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

describe('Balance Change Policy', function () {
    let owner, addr1, addr2;
    let firewall, sampleConsumer, sampleConsumerIface, balanceChangePolicy, testToken;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        const BalanceChangePolicy = await ethers.getContractFactory(
            'BalanceChangePolicy'
        );
        const SampleToken = await ethers.getContractFactory('SampleToken');

        testToken = await SampleToken.deploy();
        balanceChangePolicy = await BalanceChangePolicy.deploy();
        firewall = await FirewallFactory.deploy();
        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
        sampleConsumerIface = SampleConsumerFactory.interface;

        await firewall.setPolicyStatus(balanceChangePolicy.address, true);
        await firewall.addGlobalPolicy(sampleConsumer.address, balanceChangePolicy.address);
        await testToken.transfer(addr1.address, ethers.utils.parseEther('100'));
        await testToken.connect(addr1).approve(sampleConsumer.address, ethers.utils.parseEther('100'));
    });

    it('Firewall Balance Change policy managing tokens', async function () {
        let consumerTokens;
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1')
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('2')
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS]);
        await balanceChangePolicy.removeToken(
            sampleConsumer.address,
            ETH_ADDRESS,
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1')
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            testToken.address,
            ethers.utils.parseEther('2')
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS, testToken.address]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            addr2.address,
            ethers.utils.parseEther('2')
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS, testToken.address, addr2.address]);
        await balanceChangePolicy.removeToken(
            sampleConsumer.address,
            testToken.address,
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS, addr2.address]);
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            testToken.address,
            ethers.utils.parseEther('1')
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS, addr2.address, testToken.address]);
        await balanceChangePolicy.removeToken(
            sampleConsumer.address,
            testToken.address,
        );
        consumerTokens = await balanceChangePolicy.getConsumerTokens(sampleConsumer.address);
        expect(consumerTokens).to.eql([ETH_ADDRESS, addr2.address]);
    });

    it('Firewall Balance Change policy unapproved call above limit fails (eth)', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1')
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1.01') })
        ).to.be.revertedWith('BalanceChangePolicy: Balance change exceeds limit');
    });

    it('Firewall Balance Change policy unapproved call above limit fails (token)', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            testToken.address,
            ethers.utils.parseEther('1')
        );
        await expect(
            sampleConsumer
                .connect(addr1)
                .depositToken(testToken.address, ethers.utils.parseEther('1.01'))
        ).to.be.revertedWith('BalanceChangePolicy: Balance change exceeds limit');
    });

    it('Firewall Balance Change Or Approved calls with signature policy unapproved call above limit fails (token+eth)', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            testToken.address,
            ethers.utils.parseEther('1')
        );
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1')
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1.01') })
        ).to.be.revertedWith('BalanceChangePolicy: Balance change exceeds limit');
        await expect(
            sampleConsumer
                .connect(addr1)
                .depositToken(testToken.address, ethers.utils.parseEther('1.01'))
        ).to.be.revertedWith('BalanceChangePolicy: Balance change exceeds limit');
    });

    it('Firewall Balance Change policy unapproved call below limit passes (eth)', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1')
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

    it('Firewall Balance Change policy unapproved call below limit passes (token)', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            testToken.address,
            ethers.utils.parseEther('1')
        );
        await expect(
            sampleConsumer
                .connect(addr1)
                .depositToken(testToken.address, ethers.utils.parseEther('1'))
        ).to.not.be.reverted;
    });

    it('Firewall Balance Change policy unapproved call below limit passes (eth+token)', async function () {
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
            ethers.utils.parseEther('1')
        );
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            testToken.address,
            ethers.utils.parseEther('1')
        );
        await expect(
            sampleConsumer
                .connect(addr1)
                .depositToken(testToken.address, ethers.utils.parseEther('1'))
        ).to.not.be.reverted;
        await expect(
            sampleConsumer
                .connect(addr1)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

});

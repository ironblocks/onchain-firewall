const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Approved Vectors Policy', function () {
    let owner, addr1, addr2;
    let firewall, sampleConsumer, sampleContractUser, sampleConsumerIface, approvedVectorsPolicy;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        const SampleConsumerFactory = await ethers.getContractFactory(
            'SampleConsumer'
        );
        const SampleContractUserFactory = await ethers.getContractFactory(
            'SampleContractUser'
        );
        const ApprovedVectorsPolicy = await ethers.getContractFactory(
            'ApprovedVectorsPolicy'
        );
        sampleContractUser = await SampleContractUserFactory.deploy();
        approvedVectorsPolicy = await ApprovedVectorsPolicy.deploy();
        firewall = await FirewallFactory.deploy();
        sampleConsumer = await SampleConsumerFactory.deploy(firewall.address);
        sampleConsumerIface = SampleConsumerFactory.interface;
        await firewall.setPolicyStatus(approvedVectorsPolicy.address, true);
        await firewall.addGlobalPolicy(
            sampleConsumer.address,
            approvedVectorsPolicy.address
        );
    });

    it('gas comparison test', async function () {
        await firewall.removeGlobalPolicy(
            sampleConsumer.address,
            approvedVectorsPolicy.address
        );
        await sampleConsumer.deposit({ value: ethers.utils.parseEther('1') });
        await sampleConsumer.withdraw(ethers.utils.parseEther('1'));
    });

    it('Firewall Approved vectors, all length 1 vectors pass, all others fail', async function () {
        await expect(
            sampleContractUser.connect(addr1).deposit(
                sampleConsumer.address,
                { value: ethers.utils.parseEther("1") }
            )
        ).to.not.be.reverted;
        await expect(
            sampleContractUser.connect(addr1).withdraw(
                sampleConsumer.address,
                ethers.utils.parseEther("1"),
            )
        ).to.not.be.reverted;
        await expect(
            sampleContractUser.connect(addr1).depositAndWithdraw(
                sampleConsumer.address,
                { value: ethers.utils.parseEther("1") }
            )
        ).to.be.revertedWith("ApprovedVectorsPolicy: Unapproved Vector");
        await expect(
            sampleContractUser.connect(addr1).depositAndWithdrawAndDeposit(
                sampleConsumer.address,
                { value: ethers.utils.parseEther("1") }
            )
        ).to.be.revertedWith("ApprovedVectorsPolicy: Unapproved Vector");
    });

    it('Firewall Approved vectors, only approved vectors pass', async function () {
        const depositAndWithdrawVector = ethers.utils.solidityKeccak256(
            ['bytes4', 'bytes4'],
            [ sampleConsumerIface.getSighash('deposit()'), sampleConsumerIface.getSighash('withdraw(uint256)') ]
        );
        const depositAndWithdrawAndDepositVector = ethers.utils.solidityKeccak256(
            ['bytes4', 'bytes4', 'bytes4'],
            [
                sampleConsumerIface.getSighash('deposit()'),
                sampleConsumerIface.getSighash('withdraw(uint256)'),
                sampleConsumerIface.getSighash('deposit()'),
            ]
        );
        await approvedVectorsPolicy.setVectorHashStatus(depositAndWithdrawVector, true);
        await expect(
            sampleContractUser.connect(addr1).depositAndWithdraw(
                sampleConsumer.address,
                { value: ethers.utils.parseEther("1") }
            )
        ).to.not.be.reverted;
        await expect(
            sampleContractUser.connect(addr1).depositAndWithdrawAndDeposit(
                sampleConsumer.address,
                { value: ethers.utils.parseEther("1") }
            )
        ).to.be.revertedWith("ApprovedVectorsPolicy: Unapproved Vector");
        await approvedVectorsPolicy.setVectorHashStatus(depositAndWithdrawAndDepositVector, true);
        await expect(
            sampleContractUser.connect(addr1).depositAndWithdrawAndDeposit(
                sampleConsumer.address,
                { value: ethers.utils.parseEther("1") }
            )
        ).to.not.be.reverted;
    });


});

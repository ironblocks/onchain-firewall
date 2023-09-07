const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

describe('Approved Calls Policy', function () {
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

    it('gas comparison test', async function () {
        await sampleConsumer.deposit({ value: ethers.utils.parseEther('1') });
        await sampleConsumer.withdraw(ethers.utils.parseEther('1'));
    });

    it('Firewall Approved calls policy onlyOwner functions', async function () {
        const ApprovedCallsPolicy = await ethers.getContractFactory(
            'ApprovedCallsPolicy'
        );
        const approvedCallsPolicy =
            await ApprovedCallsPolicy.deploy();
        await expect(
            approvedCallsPolicy.connect(addr1).approveCalls(
                [`0x${'00'.repeat(32)}`],
            )
        ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('Firewall Approved calls policy unapproved call fails', async function () {
        const ApprovedCallsPolicy = await ethers.getContractFactory(
            'ApprovedCallsPolicy'
        );
        const approvedCallsPolicy =
            await ApprovedCallsPolicy.deploy();
        await firewall.setPolicyStatus(approvedCallsPolicy.address, true);
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            approvedCallsPolicy.address
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.be.revertedWith('ApprovedCallsPolicy: call hashes empty');
    });

    it('Firewall Approved calls policy admin functions', async function () {
        const ApprovedCallsPolicy = await ethers.getContractFactory(
            'ApprovedCallsPolicy'
        );
        const approvedCallsPolicy =
            await ApprovedCallsPolicy.deploy();
        await firewall.setPolicyStatus(approvedCallsPolicy.address, true);
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('setOwner(address)'),
            approvedCallsPolicy.address
        );
        const setOwnerPayload = sampleConsumerIface.encodeFunctionData(
            'setOwner(address)',
            [owner.address]
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
        await approvedCallsPolicy.approveCalls([callHash]);
        await expect(sampleConsumer.connect(owner).setOwner(owner.address)).to
            .not.be.reverted;
        await expect(
            sampleConsumer.connect(owner).setOwner(owner.address)
        ).to.be.revertedWith('ApprovedCallsPolicy: call hashes empty');
        const nextCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                owner.address,
                owner.address,
                setOwnerPayload,
                1,
            ]
        );
        await approvedCallsPolicy.approveCalls([nextCallHash]);
        await expect(
            sampleConsumer.connect(owner).setOwner(owner.address)
        ).to.be.revertedWith('ApprovedCallsPolicy: invalid call hash');
    });

    it('Firewall Approved calls bundle policy onlyOwner functions', async function () {
        const ApprovedCallsBundlePolicy = await ethers.getContractFactory(
            'ApprovedCallsBundlePolicy'
        );
        const approvedCallsBundlePolicy =
            await ApprovedCallsBundlePolicy.deploy();
        await expect(
            approvedCallsBundlePolicy.connect(addr1).approveCalls(
                [`0x${'00'.repeat(32)}`],
            )
        ).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it('Firewall Approved calls bundle policy unapproved call fails', async function () {
        const ApprovedCallsBundlePolicy = await ethers.getContractFactory(
            'ApprovedCallsBundlePolicy'
        );
        const approvedCallsBundlePolicy =
            await ApprovedCallsBundlePolicy.deploy();
        await firewall.setPolicyStatus(approvedCallsBundlePolicy.address, true);
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            approvedCallsBundlePolicy.address
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.be.revertedWith('ApprovedCallsBundlePolicy: call hashes empty');
    });

    it('Firewall Approved calls bundle policy multiple approved calls', async function () {
        const SampleContractUser = await ethers.getContractFactory(
            'SampleContractUser'
        );
        const ApprovedCallsBundlePolicy = await ethers.getContractFactory(
            'ApprovedCallsBundlePolicy'
        );
        const approvedCallsBundlePolicy =
            await ApprovedCallsBundlePolicy.deploy();
        const sampleContractUser = await SampleContractUser.deploy();

        await firewall.setPolicyStatus(approvedCallsBundlePolicy.address, true);
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            approvedCallsBundlePolicy.address
        );

        const depositPayload = sampleConsumerIface.encodeFunctionData('deposit()');
        const withdrawPayload = sampleConsumerIface.encodeFunctionData('withdraw(uint256)', [ethers.utils.parseEther('1')]);
        // +2 instead of +1 because we need to call 'approveCalls'
        const executionBlock = (await ethers.provider.getBlockNumber()) + 2;

        const depositCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256', 'uint256'],
            [
                sampleConsumer.address,
                sampleContractUser.address,
                owner.address,
                depositPayload,
                ethers.utils.parseEther('1'),
                executionBlock,
            ]
        );
        const withdrawCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256', 'uint256'],
            [
                sampleConsumer.address,
                sampleContractUser.address,
                owner.address,
                withdrawPayload,
                ethers.utils.parseEther('0'),
                executionBlock,
            ]
        );
        // We pass the calls in reverse order because the bundle policy pops the last element
        await approvedCallsBundlePolicy.approveCalls([withdrawCallHash, depositCallHash]);

        await expect(
            sampleContractUser
                .connect(owner)
                .depositAndWithdraw(sampleConsumer.address, { value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

    it('Firewall Approved calls bundle policy wrong call order fails', async function () {
        const SampleContractUser = await ethers.getContractFactory(
            'SampleContractUser'
        );
        const ApprovedCallsBundlePolicy = await ethers.getContractFactory(
            'ApprovedCallsBundlePolicy'
        );
        const approvedCallsBundlePolicy =
            await ApprovedCallsBundlePolicy.deploy();
        const sampleContractUser = await SampleContractUser.deploy();

        await firewall.setPolicyStatus(approvedCallsBundlePolicy.address, true);
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            approvedCallsBundlePolicy.address
        );

        const depositPayload = sampleConsumerIface.encodeFunctionData('deposit()');
        const withdrawPayload = sampleConsumerIface.encodeFunctionData('withdraw(uint256)', [ethers.utils.parseEther('1')]);
        // +2 instead of +1 because we need to call 'approveCalls'
        const executionBlock = (await ethers.provider.getBlockNumber()) + 2;

        const depositCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256', 'uint256'],
            [
                sampleConsumer.address,
                sampleContractUser.address,
                owner.address,
                depositPayload,
                ethers.utils.parseEther('1'),
                executionBlock,
            ]
        );
        const withdrawCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256', 'uint256'],
            [
                sampleConsumer.address,
                sampleContractUser.address,
                owner.address,
                withdrawPayload,
                ethers.utils.parseEther('0'),
                executionBlock,
            ]
        );
        await approvedCallsBundlePolicy.approveCalls([depositCallHash, withdrawCallHash]);

        await expect(
            sampleContractUser
                .connect(owner)
                .depositAndWithdraw(sampleConsumer.address, { value: ethers.utils.parseEther('1') })
        ).to.be.revertedWith('ApprovedCallsBundlePolicy: invalid call hash');
    });

    it('Firewall Approved calls bundle policy admin functions', async function () {
        const ApprovedCallsBundlePolicy = await ethers.getContractFactory(
            'ApprovedCallsBundlePolicy'
        );
        const approvedCallsBundlePolicy =
            await ApprovedCallsBundlePolicy.deploy();
        await firewall.setPolicyStatus(approvedCallsBundlePolicy.address, true);
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('setOwner(address)'),
            approvedCallsBundlePolicy.address
        );
        const setOwnerPayload = sampleConsumerIface.encodeFunctionData(
            'setOwner(address)',
            [owner.address]
        );
        // +2 instead of +1 because we need to call 'approveCalls'
        const executionBlock = (await ethers.provider.getBlockNumber()) + 2;
        const callHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256', 'uint256'],
            [
                sampleConsumer.address,
                owner.address,
                owner.address,
                setOwnerPayload,
                0,
                executionBlock,
            ]
        );
        await approvedCallsBundlePolicy.approveCalls([callHash]);
        await expect(sampleConsumer.connect(owner).setOwner(owner.address)).to
            .not.be.reverted;
        await expect(
            sampleConsumer.connect(owner).setOwner(owner.address)
        ).to.be.revertedWith('ApprovedCallsBundlePolicy: call hashes empty');
        const nextCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256', 'uint256'],
            [
                sampleConsumer.address,
                owner.address,
                owner.address,
                setOwnerPayload,
                0,
                executionBlock,
            ]
        );
        await approvedCallsBundlePolicy.approveCalls([nextCallHash]);
        await expect(
            sampleConsumer.connect(owner).setOwner(owner.address)
        ).to.be.revertedWith('ApprovedCallsBundlePolicy: invalid call hash');
    });

    it('Firewall Approved calls with signature policy only signer functions', async function () {
        const ApprovedCallsWithSignaturePolicy = await ethers.getContractFactory(
            'ApprovedCallsWithSignaturePolicy'
        );
        const approvedCallsWithSignaturePolicy =
            await ApprovedCallsWithSignaturePolicy.deploy();
        await expect(
            approvedCallsWithSignaturePolicy.connect(addr1).approveCalls(
                [`0x${'00'.repeat(32)}`],
                0,
                addr2.address,
                addr2.address
            )
        ).to.be.revertedWith(`AccessControl: account ${addr1.address.toLowerCase()} is missing role 0xe2f4eaae4a9751e85a3e4a7b9587827a877f29914755229b07a7b2da98285f70`);
    });

    it('Firewall Approved calls with signature policy unapproved call fails', async function () {
        const ApprovedCallsWithSignaturePolicy = await ethers.getContractFactory(
            'ApprovedCallsWithSignaturePolicy'
        );
        const approvedCallsWithSignaturePolicy =
            await ApprovedCallsWithSignaturePolicy.deploy();
        await firewall.setPolicyStatus(approvedCallsWithSignaturePolicy.address, true);
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            approvedCallsWithSignaturePolicy.address
        );
        await expect(
            sampleConsumer
                .connect(addr2)
                .deposit({ value: ethers.utils.parseEther('1') })
        ).to.be.revertedWith('ApprovedCallsWithSignaturePolicy: call hashes empty');
    });

    it('Firewall Approved calls with signature policy approved calls', async function () {
        const SampleContractUser = await ethers.getContractFactory(
            'SampleContractUser'
        );
        const ApprovedCallsWithSignaturePolicy = await ethers.getContractFactory(
            'ApprovedCallsWithSignaturePolicy'
        );
        const approvedCallsWithSignaturePolicy =
            await ApprovedCallsWithSignaturePolicy.deploy();
        await approvedCallsWithSignaturePolicy.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('SIGNER_ROLE')), owner.address);
        const sampleContractUser = await SampleContractUser.deploy();

        await firewall.setPolicyStatus(approvedCallsWithSignaturePolicy.address, true);
        await firewall.addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            approvedCallsWithSignaturePolicy.address
        );

        const depositPayload = sampleConsumerIface.encodeFunctionData('deposit()');
        const withdrawPayload = sampleConsumerIface.encodeFunctionData('withdraw(uint256)', [ethers.utils.parseEther('1')]);

        const depositCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                sampleContractUser.address,
                addr1.address,
                depositPayload,
                ethers.utils.parseEther('1'),
            ]
        );
        const withdrawCallHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                sampleConsumer.address,
                sampleContractUser.address,
                addr1.address,
                withdrawPayload,
                ethers.utils.parseEther('0'),
            ]
        );
        const packed = ethers.utils.solidityPack(
            ['bytes32[]', 'uint256', 'address', 'address', 'uint256'],
            [
                [withdrawCallHash, depositCallHash],
                ethers.utils.parseEther('1'), // expiration, yuge numba
                addr1.address,
                sampleContractUser.address,
                0
            ]
        );
        const messageHash = ethers.utils.solidityKeccak256(
            ['bytes'], [packed]
        );
        const messageHashBytes = ethers.utils.arrayify(messageHash)
        const signature = await owner.signMessage(messageHashBytes);
        // We pass the calls in reverse order because the bundle policy pops the last element
        await approvedCallsWithSignaturePolicy.approveCallsViaSignature(
            [withdrawCallHash, depositCallHash],
            ethers.utils.parseEther('1'),
            addr1.address,
            sampleContractUser.address,
            0,
            signature
        );

        await expect(
            sampleContractUser
                .connect(addr1)
                .depositAndWithdraw(sampleConsumer.address, { value: ethers.utils.parseEther('1') })
        ).to.not.be.reverted;
    });

});

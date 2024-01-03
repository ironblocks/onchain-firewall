const { expect } = require('chai');
const { ethers } = require('hardhat');

const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

// This tests an existing TransparentUpgradeableProxy contract that has been deployed regularly,
// and then upgraded to point it's implementation to the FirewallTransparentUpgradeableProxy contract.
describe('Firewall Consumer Upgradeable Proxy', function () {
    let owner, addr1, addr2, proxyAdmin, firewallAdmin, firewallProxyIntercept;
    let firewall, sampleConsumer, sampleConsumerIface, firewallProxyInterceptIface;

    beforeEach(async function () {
        [owner, addr1, addr2, firewallAdmin] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        firewall = await FirewallFactory.deploy();
        const ProxyAdminFactory = await ethers.getContractFactory('ProxyAdmin');
        proxyAdmin = await ProxyAdminFactory.deploy();
        const TransparentUpgradeableProxyFactory = await ethers.getContractFactory(
            'TransparentUpgradeableProxy'
        );
        const FirewallProxyInterceptFactory = await ethers.getContractFactory(
            'FirewallProxyIntercept'
        );
        const SampleConsumerUpgradeableFactory = await ethers.getContractFactory(
            'SampleConsumerUpgradeable'
        );
        const sampleConsumerImplementation = await SampleConsumerUpgradeableFactory.deploy();
        sampleConsumerIface = SampleConsumerUpgradeableFactory.interface;
        firewallProxyInterceptIface = FirewallProxyInterceptFactory.interface;
        const sampleConsumerProxy = await TransparentUpgradeableProxyFactory.deploy(
            sampleConsumerImplementation.address,
            proxyAdmin.address,
            sampleConsumerIface.encodeFunctionData('initialize', []),
        );

        firewallProxyIntercept = await FirewallProxyInterceptFactory.deploy(
            sampleConsumerImplementation.address,
            proxyAdmin.address,
        );
        // await proxyAdmin.changeProxyAdmin(sampleConsumerProxy.address, proxyAdmin.address);
        await proxyAdmin.upgradeAndCall(
            sampleConsumerProxy.address,
            firewallProxyIntercept.address,
            firewallProxyInterceptIface.encodeFunctionData(
                'initialize(address,address,address)',
                [firewall.address, firewallAdmin.address, sampleConsumerImplementation.address]
            )
        );
        sampleConsumer = await SampleConsumerUpgradeableFactory.attach(sampleConsumerProxy.address);
    });

    it('Firewall Proxy change firewall', async function () {
        await expect(
            proxyAdmin
                .connect(addr2)
                .upgradeAndCall(
                    sampleConsumer.address,
                    firewallProxyIntercept.address,
                    firewallProxyInterceptIface.encodeFunctionData(
                        'changeFirewall(address)',
                        [addr1.address]
                    )
                )
        ).to.be.revertedWith('Ownable: caller is not the owner');
        const firewallAddressBefore = ethers.utils.hexStripZeros(await ethers.provider.getStorageAt(
            sampleConsumer.address,
            '0x5dd2e3b890564a8f99f7f203f226a27a8aa59aee19a4ece5cf5eaa77ab91f661'
        ));
        expect(firewallAddressBefore).to.equal(firewall.address.toLowerCase());
        await proxyAdmin.upgradeAndCall(
            sampleConsumer.address,
            firewallProxyIntercept.address,
            firewallProxyInterceptIface.encodeFunctionData(
                'changeFirewall(address)',
                [addr1.address]
            )
        );
        const firewallAddressAfter = ethers.utils.hexStripZeros(await ethers.provider.getStorageAt(
            sampleConsumer.address,
            '0x5dd2e3b890564a8f99f7f203f226a27a8aa59aee19a4ece5cf5eaa77ab91f661'
        ));
        expect(firewallAddressAfter).to.equal(addr1.address.toLowerCase());
    });

    it('Firewall Proxy change firewall admin', async function () {
        await expect(
            proxyAdmin
                .connect(addr2)
                .upgradeAndCall(
                    sampleConsumer.address,
                    firewallProxyIntercept.address,
                    firewallProxyInterceptIface.encodeFunctionData(
                        'changeFirewallAdmin(address)',
                        [addr1.address]
                    )
                )
        ).to.be.revertedWith('Ownable: caller is not the owner');
        const firewallAdminAddressBefore = ethers.utils.hexStripZeros(await ethers.provider.getStorageAt(
            sampleConsumer.address,
            '0x29982a6ac507a2a707ced6dee5d76285dd49725db977de83d9702c628c974135'
        ));
        expect(firewallAdminAddressBefore).to.equal(firewallAdmin.address.toLowerCase());
        await proxyAdmin.upgradeAndCall(
            sampleConsumer.address,
            firewallProxyIntercept.address,
            firewallProxyInterceptIface.encodeFunctionData(
                'changeFirewallAdmin(address)',
                [addr1.address]
            )
        );
        const firewallAdminAddressAfter = ethers.utils.hexStripZeros(await ethers.provider.getStorageAt(
            sampleConsumer.address,
            '0x29982a6ac507a2a707ced6dee5d76285dd49725db977de83d9702c628c974135'
        ));
        expect(firewallAdminAddressAfter).to.equal(addr1.address.toLowerCase());
    });

    it('Firewall Approved calls policy unapproved call fails', async function () {
        const ApprovedCallsPolicy = await ethers.getContractFactory(
            'ApprovedCallsPolicy'
        );
        const approvedCallsPolicy =
            await ApprovedCallsPolicy.deploy();
        await firewall.setPolicyStatus(approvedCallsPolicy.address, true);
        await firewall.connect(firewallAdmin).addPolicy(
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
        await firewall.connect(firewallAdmin).addPolicy(
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
        await firewall.connect(firewallAdmin).addPolicy(
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
        await firewall.connect(firewallAdmin).addPolicy(
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
        await firewall.connect(firewallAdmin).addPolicy(
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
        await firewall.connect(firewallAdmin).addPolicy(
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

    it('Firewall balance change', async function () {
        const BalanceChangePolicy = await ethers.getContractFactory(
            'BalanceChangePolicy'
        );
        const balanceChangePolicy = await BalanceChangePolicy.deploy();
        await firewall.setPolicyStatus(balanceChangePolicy.address, true);
        await firewall.connect(firewallAdmin).addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('deposit()'),
            balanceChangePolicy.address
        );
        await firewall.connect(firewallAdmin).addPolicy(
            sampleConsumer.address,
            sampleConsumerIface.getSighash('withdraw(uint256)'),
            balanceChangePolicy.address
        );
        await expect(
            balanceChangePolicy.connect(addr1).setConsumerMaxBalanceChange(
                sampleConsumer.address,
                ETH_ADDRESS,
                ethers.utils.parseEther('25')
        )
        ).to.be.revertedWith('Ownable: caller is not the owner');
        await balanceChangePolicy.setConsumerMaxBalanceChange(
            sampleConsumer.address,
            ETH_ADDRESS,
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

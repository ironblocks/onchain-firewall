const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');
const GnosisSafeArtifact = require('@gnosis.pm/safe-contracts/build/artifacts/contracts/GnosisSafe.sol/GnosisSafe.json');
const GnosisSafeProxyArtifact = require('@gnosis.pm/safe-contracts/build/artifacts/contracts/proxies/GnosisSafeProxy.sol/GnosisSafeProxy.json');

const utils = require('./utils/utils');

describe('Firewall (Safe integration)', function () {
    let owner, addr1, addr2, signer1, signer2;
    let firewall;
    let gnosisSafe, firewallGuard, gnosisSafeIface;
    const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

    beforeEach(async function () {
        [owner, addr1, addr2, signer1, signer2] = await ethers.getSigners();
        const FirewallFactory = await ethers.getContractFactory('Firewall');
        firewall = await upgrades.deployProxy(FirewallFactory, []);

        const GnosisSafe = await ethers.getContractFactoryFromArtifact(
            GnosisSafeArtifact
        );
        const GnosisSafeProxy = await ethers.getContractFactoryFromArtifact(
            GnosisSafeProxyArtifact
        );
        gnosisSafeIface = GnosisSafe.interface;
        const gnosisSafeMasterCopy = await GnosisSafe.deploy();
        const proxy = await GnosisSafeProxy.deploy(
            gnosisSafeMasterCopy.address
        );
        gnosisSafe = await GnosisSafe.attach(proxy.address);
        await gnosisSafe.setup(
            [signer1.address, signer2.address],
            1,
            ZERO_ADDRESS,
            '0x',
            ZERO_ADDRESS,
            ZERO_ADDRESS,
            0,
            ZERO_ADDRESS
        );

        const FirewallGuardFactory = await ethers.getContractFactory(
            'FirewallGuard'
        );
        firewallGuard = await FirewallGuardFactory.deploy(
            gnosisSafe.address,
            firewall.address,
            gnosisSafe.address,
            10000
        );
        const tx = {
            to: gnosisSafe.address,
            data: GnosisSafe.interface.encodeFunctionData(
                'setGuard(address)',
                [firewallGuard.address]
            ),
        };
        await utils.execSafeTx(gnosisSafe, tx, [signer1]);
    });

    it('Firewall Admin call policy approved/unapproved calls', async function () {
        const AdminCallPolicy = await ethers.getContractFactory(
            'AdminCallPolicy'
        );
        const adminCallPolicy = await AdminCallPolicy.deploy();

        await firewall.setPolicyStatus(adminCallPolicy.address, true);
        const addPolicyTx = {
            to: firewall.address,
            data: firewall.interface.encodeFunctionData('addPolicy(address,bytes4,address)', [firewallGuard.address, gnosisSafeIface.getSighash('execTransaction'), adminCallPolicy.address])
        };
        await utils.execSafeTx(gnosisSafe, addPolicyTx, [signer1]);
        const args1 = await utils.getSafeExecTxArgs(
            gnosisSafe,
            { to: ZERO_ADDRESS },
            [signer1]
        );
        await expect(
            gnosisSafe.execTransaction(
                args1.to,
                args1.value,
                args1.data,
                args1.operation,
                args1.safeTxGas,
                args1.baseGas,
                args1.gasPrice,
                args1.gasToken,
                args1.refundReceiver,
                args1.signatures
            )
        ).to.be.revertedWith('AdminCallPolicy: Call not approved');

        const args2 = await utils.getSafeExecTxArgs(
            gnosisSafe,
            { to: ZERO_ADDRESS },
            [signer1]
        );

        const execTransactionPayload = gnosisSafeIface.encodeFunctionData(
            'execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)',
            [args2.to, args2.value, args2.data, args2.operation, args2.safeTxGas, args2.baseGas, args2.gasPrice, args2.gasToken, args2.refundReceiver, args2.signatures]
        );
        const callHash = ethers.utils.solidityKeccak256(
            ['address', 'address', 'address', 'bytes', 'uint256'],
            [
                firewallGuard.address,
                signer1.address,
                signer1.address,
                execTransactionPayload,
                0,
            ]
        );
        await adminCallPolicy.approveCall(callHash);
        await expect(gnosisSafe.connect(signer1).execTransaction(
            args2.to,
            args2.value,
            args2.data,
            args2.operation,
            args2.safeTxGas,
            args2.baseGas,
            args2.gasPrice,
            args2.gasToken,
            args2.refundReceiver,
            args2.signatures
        )).to.not.be.reverted;
    });

    it('Can bypass firewall with delay', async function () {
        const AdminCallPolicy = await ethers.getContractFactory(
            'AdminCallPolicy'
        );
        const adminCallPolicy = await AdminCallPolicy.deploy();

        await firewall.setPolicyStatus(adminCallPolicy.address, true);
        const addPolicyTx = {
            to: firewall.address,
            data: firewall.interface.encodeFunctionData('addPolicy(address,bytes4,address)', [firewallGuard.address, gnosisSafeIface.getSighash('execTransaction'), adminCallPolicy.address])
        };
        (await utils.execSafeTx(gnosisSafe, addPolicyTx, [signer1])).wait();
        const args = await utils.getSafeExecTxArgs(
            gnosisSafe,
            { to: ZERO_ADDRESS },
            [signer1]
        );
        await firewallGuard.bypassGuard(
            args.to,
            args.value,
            args.data,
            args.operation,
            args.safeTxGas,
            args.baseGas,
            args.gasPrice,
            args.gasToken,
            args.refundReceiver,
            args.signatures
        );
        await expect(
            gnosisSafe.execTransaction(
                args.to,
                args.value,
                args.data,
                args.operation,
                args.safeTxGas,
                args.baseGas,
                args.gasPrice,
                args.gasToken,
                args.refundReceiver,
                args.signatures
            )
        ).to.be.revertedWith('AdminCallPolicy: Call not approved');
        await ethers.provider.send('evm_increaseTime', [10001]);
        await expect(
            gnosisSafe.execTransaction(
                args.to,
                args.value,
                args.data,
                args.operation,
                args.safeTxGas,
                args.baseGas,
                args.gasPrice,
                args.gasToken,
                args.refundReceiver,
                args.signatures
            )
        ).to.not.be.reverted;
    });

});

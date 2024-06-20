import hre from 'hardhat';
import { expect } from 'chai';

import { CounterWithTPFirewallConsumer, CounterWithTPFirewallConsumer__factory } from '../typechain-types';

describe('UpgradeableCounter With TransparentProxy FirewallConsumer', () => {
    hre.upgrades.silenceWarnings();

    let CounterWithTPFirewallConsumerFactory: CounterWithTPFirewallConsumer__factory;
    let proxy: CounterWithTPFirewallConsumer;

    beforeEach(async () => {
        CounterWithTPFirewallConsumerFactory = await hre.ethers.getContractFactory('CounterWithTPFirewallConsumer');

        // prettier-ignore
        proxy = (
            await hre.upgrades.deployProxy(
                CounterWithTPFirewallConsumerFactory,
                { unsafeAllow: ['constructor'] }
            )
        ) as unknown as CounterWithTPFirewallConsumer;
    });

    describe('Sanity Checks', () => {
        it('can be initialized as a TransparentUpgradeableProxy', async function () {
            expect(await proxy.getCount()).to.equal(0);
        });

        it('.increment() works through the proxy', async function () {
            await proxy.increment();
            expect(await proxy.getCount()).to.equal(1);
        });

        it('.decrement() works through the proxy', async function () {
            await proxy.increment();
            await proxy.decrement();
            expect(await proxy.getCount()).to.equal(0);
        });
    });

    describe('FirewallAdmin', () => {
        it('defaults to the zero address if not initialized with the proxy setup', async function () {
            const firewallAdmin = await proxy.firewallAdmin();
            expect(firewallAdmin).to.equal(hre.ethers.ZeroAddress);
        });

        it('cannot be initialized by a non-proxy-admin', async function () {
            const [_, nonProxyAdmin] = await hre.ethers.getSigners();
            const initializationTx = proxy.connect(nonProxyAdmin).initializeFirewallAdmin(hre.ethers.ZeroAddress);

            await expect(initializationTx).to.be.revertedWith('ProxyFirewallConsumerBase: sender is not allowed');
        });

        it('cannot be initialized to a zero address', async function () {
            const initializationTx = proxy.initializeFirewallAdmin(hre.ethers.ZeroAddress);
            await expect(initializationTx).to.be.revertedWith('ProxyFirewallConsumerBase: zero address');
        });

        it('cannot be initialized twice', async function () {
            const [_, newFirewallAdmin] = await hre.ethers.getSigners();

            // Set it once
            await proxy.initializeFirewallAdmin(newFirewallAdmin.address);
            await proxy.connect(newFirewallAdmin).acceptFirewallAdmin();

            // Try to set it again
            const initializationTx = proxy.initializeFirewallAdmin(newFirewallAdmin.address);
            await expect(initializationTx).to.be.revertedWith('ProxyFirewallConsumerBase: admin already set');
        });

        it('can be initialized by the proxy admin', async function () {
            const [proxyAdmin, newFirewallAdmin] = await hre.ethers.getSigners();

            await proxy.connect(proxyAdmin).initializeFirewallAdmin(newFirewallAdmin.address);
            await proxy.connect(newFirewallAdmin).acceptFirewallAdmin();

            const firewallAdmin = await proxy.firewallAdmin();
            expect(firewallAdmin).to.equal(newFirewallAdmin.address);
        });

        it('can be initialized if not already set', async function () {
            const [_, newFirewallAdmin, otherFirewallAdmin] = await hre.ethers.getSigners();

            // Set it once
            await proxy.initializeFirewallAdmin(newFirewallAdmin.address);

            // Try to set it again to a different address
            await proxy.initializeFirewallAdmin(otherFirewallAdmin.address);
            await proxy.connect(otherFirewallAdmin).acceptFirewallAdmin();

            expect(await proxy.firewallAdmin()).to.equal(otherFirewallAdmin.address);
        });
    });
});

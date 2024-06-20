import hre from 'hardhat';
import { expect } from 'chai';

import { CounterWithBPFirewallConsumer, CounterWithBPFirewallConsumer__factory } from '../typechain-types';

describe('UpgradeableCounter With BeaconProxy FirewallConsumer', () => {
    hre.upgrades.silenceWarnings();

    let CounterWithBPFirewallConsumerFactory: CounterWithBPFirewallConsumer__factory;

    let beacon: any;
    let beaconProxy: CounterWithBPFirewallConsumer;

    beforeEach(async () => {
        CounterWithBPFirewallConsumerFactory = await hre.ethers.getContractFactory('CounterWithBPFirewallConsumer');

        // prettier-ignore
        beacon = await hre.upgrades.deployBeacon(
            CounterWithBPFirewallConsumerFactory,
            { unsafeAllow: ['constructor'] }
        );

        // prettier-ignore
        beaconProxy = (
            await hre.upgrades.deployBeaconProxy(
                await beacon.getAddress(),
                CounterWithBPFirewallConsumerFactory
            )
        ) as unknown as CounterWithBPFirewallConsumer;
    });

    describe('Sanity Checks', () => {
        it('can be initialized as a BeaconProxy', async function () {
            expect(await beaconProxy.getCount()).to.equal(0);
        });

        it('.increment() works through the proxy', async function () {
            await beaconProxy.increment();
            expect(await beaconProxy.getCount()).to.equal(1);
        });

        it('.decrement() works through the proxy', async function () {
            await beaconProxy.increment();
            await beaconProxy.decrement();
            expect(await beaconProxy.getCount()).to.equal(0);
        });
    });

    describe('FirewallAdmin', () => {
        it('defaults to the zero address if not initialized with the proxy setup', async function () {
            const firewallAdmin = await beaconProxy.firewallAdmin();
            expect(firewallAdmin).to.equal(hre.ethers.ZeroAddress);
        });

        it('cannot be initialized by a non-proxy-admin', async function () {
            const [_, nonProxyAdmin] = await hre.ethers.getSigners();
            const initializationTx = beaconProxy.connect(nonProxyAdmin).initializeFirewallAdmin(hre.ethers.ZeroAddress);

            await expect(initializationTx).to.be.revertedWith('ProxyFirewallConsumerBase: sender is not allowed');
        });

        it('cannot be initialized to a zero address', async function () {
            const initializationTx = beaconProxy.initializeFirewallAdmin(hre.ethers.ZeroAddress);
            await expect(initializationTx).to.be.revertedWith('ProxyFirewallConsumerBase: zero address');
        });

        it('cannot be initialized twice', async function () {
            const [_, newFirewallAdmin] = await hre.ethers.getSigners();

            // Set it once
            await beaconProxy.initializeFirewallAdmin(newFirewallAdmin.address);
            await beaconProxy.connect(newFirewallAdmin).acceptFirewallAdmin();

            // Try to set it again
            const initializationTx = beaconProxy.initializeFirewallAdmin(newFirewallAdmin.address);
            await expect(initializationTx).to.be.revertedWith('ProxyFirewallConsumerBase: admin already set');
        });

        it('can be initialized by the beacon owner', async function () {
            const [beaconOwner, newFirewallAdmin] = await hre.ethers.getSigners();

            await beaconProxy.initializeFirewallAdmin(newFirewallAdmin.address);
            await beaconProxy.connect(newFirewallAdmin).acceptFirewallAdmin();

            const firewallAdmin = await beaconProxy.firewallAdmin();
            expect(firewallAdmin).to.equal(newFirewallAdmin.address);
        });

        it('can be initialized if not already set', async function () {
            const [_, newFirewallAdmin, otherFirewallAdmin] = await hre.ethers.getSigners();

            // Set it once
            await beaconProxy.initializeFirewallAdmin(newFirewallAdmin.address);

            // Try to set it again to a different address
            await beaconProxy.initializeFirewallAdmin(otherFirewallAdmin.address);
            await beaconProxy.connect(otherFirewallAdmin).acceptFirewallAdmin();

            expect(await beaconProxy.firewallAdmin()).to.equal(otherFirewallAdmin.address);
        });
    });
});

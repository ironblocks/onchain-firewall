// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2024
pragma solidity ^0.8;

import {ProxyFirewallConsumerBase} from "./ProxyFirewallConsumerBase.sol";

/**
 * @title BeaconProxyFirewallConsumer
 * @notice this extension allows the Beacon Proxy Owner to initialize the firewall admin even if the contract was originally deployed
 * with a zero-address in the constructor or if the contract is upgradeable and the proxy was initialized before this implementation was deployed
 */
contract BeaconProxyFirewallConsumer is ProxyFirewallConsumerBase {
    // This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1
    bytes32 private constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Beacon Proxy Owner only function, allows the Beacon Proxy Owner to initialize the firewall admin in the following cases:
     * - If the contract was originally deployed with a zero-address in the constructor (for various reasons)
     * - Or, if the contract is upgradeable and the proxy was initialized before this implementation was deployed
     * @param _firewallAdmin address of the firewall admin
     */
    function initializeFirewallAdmin(address _firewallAdmin) isAllowedInitializer(BEACON_SLOT) external {
        _initializeFirewallAdmin(_firewallAdmin);
    }
}
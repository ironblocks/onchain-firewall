// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2024
pragma solidity ^0.8;

import {ProxyFirewallConsumerBase} from "./ProxyFirewallConsumerBase.sol";

/**
 * @title TransparentProxyFirewallConsumer
 * @notice For proxies that implement ERC1967 with an admin slot, this extension allows the Proxy Admin to initialize the firewall admin
 * even when the contract was originally deployed with a zero-address in the constructor or if the contract is upgradeable and the proxy was initialized before this implementation was deployed
 */
contract TransparentProxyFirewallConsumer is ProxyFirewallConsumerBase {
    // This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1
    bytes32 private constant PROXY_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Proxy Admin only function, allows the Proxy Admin to initialize the firewall admin in the following cases:
     * - If the contract was originally deployed with a zero-address in the constructor (for various reasons)
     * - Or, if the contract is upgradeable and the proxy was initialized before this implementation was deployed
     * @param _firewallAdmin address of the firewall admin
     */
    function initializeFirewallAdmin(address _firewallAdmin) isAllowedInitializer(PROXY_ADMIN_SLOT) external {
        _initializeFirewallAdmin(_firewallAdmin);
    }
}
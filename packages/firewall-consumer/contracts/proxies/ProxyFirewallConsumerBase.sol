// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2024
pragma solidity ^0.8;

import {FirewallConsumerBase} from "../FirewallConsumerBase.sol";
import {IOwnable} from "../interfaces/IOwnable.sol";

/**
 * @title BeaconProxyFirewallConsumer
 * @notice this extension allows the Beacon Proxy Owner to initialize the firewall admin even if the contract was originally deployed
 * with a zero-address in the constructor or if the contract is upgradeable and the proxy was initialized before this implementation was deployed
 */
contract ProxyFirewallConsumerBase is FirewallConsumerBase(address(0), address(0)) {
    bytes32 private constant FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall.admin")) - 1);

    // This slot is used to store the new firewall admin address (when changing admin)
    bytes32 private constant NEW_FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.new.firewall.admin")) - 1);

    modifier isAllowedInitializer(bytes32 _admin_memory_slot) {
        address initializerAddress = _getAddressBySlot(_admin_memory_slot);
        address initializerOwner = IOwnable(initializerAddress).owner();
        require(msg.sender == initializerOwner, "ProxyFirewallConsumerBase: sender is not allowed");
        _;
    }

    /**
     * @dev Beacon Proxy Owner only function, allows the Beacon Proxy Owner to initialize the firewall admin in the following cases:
     * - If the contract was originally deployed with a zero-address in the constructor (for various reasons)
     * - Or, if the contract is upgradeable and the proxy was initialized before this implementation was deployed
     * @param _firewallAdmin address of the firewall admin
     */
    function _initializeFirewallAdmin(address _firewallAdmin) internal {
        require(_firewallAdmin != address(0), "ProxyFirewallConsumerBase: zero address");
        require(_getAddressBySlot(FIREWALL_ADMIN_STORAGE_SLOT) == address(0), "ProxyFirewallConsumerBase: admin already set");

        _setAddressBySlot(NEW_FIREWALL_ADMIN_STORAGE_SLOT, _firewallAdmin);
    }
}
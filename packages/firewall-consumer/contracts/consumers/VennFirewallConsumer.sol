// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2024
pragma solidity ^0.8.0;

import {VennFirewallConsumerBase} from "./VennFirewallConsumerBase.sol";

/**
 * @title Firewall Consumer
 * @author David Benchimol @ Ironblocks 
 * @dev This contract is a parent contract that can be used to add firewall protection to any contract.
 *
 * The contract must initializes with the firewall contract disabled, and the deployer
 * as the firewall admin.
 *
 */
contract VennFirewallConsumer is VennFirewallConsumerBase(address(0), msg.sender) {
}

// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "./FirewallPolicyBase.sol";

/**
 * @dev This policy doesn't allows blocked addresses on a blocklist to call the protected method
 *
 */
contract BlocklistPolicy is FirewallPolicyBase {

    mapping (address => mapping (address => bool)) public consumerBlocklist;

    function preExecution(address consumer, address sender, bytes calldata, uint256) external view override {
        require(!consumerBlocklist[consumer][sender], "BlocklistPolicy: Sender not allowed");
    }

    function postExecution(address, address, bytes calldata, uint256) external override {
        // Do nothing
    }

    function setConsumerBlocklist(address consumer, address[] calldata accounts, bool status) external onlyRole(POLICY_ADMIN_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            consumerBlocklist[consumer][accounts[i]] = status;
        }
    }
}

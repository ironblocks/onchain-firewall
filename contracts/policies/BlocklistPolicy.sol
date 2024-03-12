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

    mapping (address consumer => mapping (address caller => bool isCallerBlocked)) public consumerBlocklist;

    function preExecution(address consumer, address sender, bytes calldata, uint) external view override {
        require(!consumerBlocklist[consumer][sender], "BlocklistPolicy: Sender not allowed");
    }

    function postExecution(address, address, bytes calldata, uint) external override {
        // Do nothing
    }

    function setConsumerBlocklist(address consumer, address[] calldata accounts, bool status) external onlyRole(POLICY_ADMIN_ROLE) {
        for (uint i = 0; i < accounts.length; i++) {
            consumerBlocklist[consumer][accounts[i]] = status;
        }
    }
}

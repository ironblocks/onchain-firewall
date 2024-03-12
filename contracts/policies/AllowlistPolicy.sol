// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "./FirewallPolicyBase.sol";

/**
 * @dev This policy only allows addresses on an allowlist to call the protected method
 *
 */
contract AllowlistPolicy is FirewallPolicyBase {

    mapping (address consumer => mapping (address caller => bool isAllowed)) public consumerAllowlist;

    function preExecution(address consumer, address sender, bytes calldata, uint) external view override {
        require(consumerAllowlist[consumer][sender], "AllowlistPolicy: Sender not allowed");
    }

    function postExecution(address, address, bytes calldata, uint) external override {
        // Do nothing
    }

    function setConsumerAllowlist(address consumer, address[] calldata accounts, bool status) external onlyRole(POLICY_ADMIN_ROLE) {
        for (uint i = 0; i < accounts.length; i++) {
            consumerAllowlist[consumer][accounts[i]] = status;
        }
    }
}

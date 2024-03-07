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

    mapping (address => mapping (address => bool)) public consumerAllowlist;

    function preExecution(address consumer, address sender, bytes calldata, uint256) external view override {
        require(consumerAllowlist[consumer][sender], "AllowlistPolicy: Sender not allowed");
    }

    function postExecution(address, address, bytes calldata, uint256) external override {
        // Do nothing
    }

    function setConsumerAllowlist(address consumer, address[] calldata accounts, bool status) external onlyRole(POLICY_ADMIN_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            consumerAllowlist[consumer][accounts[i]] = status;
        }
    }
}

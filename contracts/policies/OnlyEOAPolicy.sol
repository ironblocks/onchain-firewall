// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "./FirewallPolicyBase.sol";

/**
 * @dev This policy only allows EOAs to interact with the consumer.
 *
 * Note that if you want specific contracts to be able to interact with the consumer,
 * then use the combined policies policy with the allowlist policy
 *
 */
contract OnlyEOAPolicy is FirewallPolicyBase {

    function preExecution(address, address sender, bytes calldata, uint) external view override {
        require(sender == tx.origin, "ONLY EOA");
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It does nothing in this policy.
     */
    function postExecution(address, address, bytes calldata, uint) external override {}

}

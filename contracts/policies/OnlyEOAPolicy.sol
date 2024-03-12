// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "./FirewallPolicyBase.sol";

/**
 * @dev This policy only allows EOAs to interact with the consumer.
 *
 * Note that we have an `allowedContracts` mapping, in case another approved contract needs
 * to be able to call this method.
 *
 */
contract OnlyEOAPolicy is FirewallPolicyBase {

    mapping (address contractAddress => bool isAllowed) public allowedContracts;

    function preExecution(address, address sender, bytes calldata, uint) external view override {
        require(sender == tx.origin || allowedContracts[sender], "ONLY EOA");
    }

    function postExecution(address, address, bytes calldata, uint) external override {}

    function setAllowedContracts(address contractAddress, bool status) external onlyRole(POLICY_ADMIN_ROLE) {
        allowedContracts[contractAddress] = status;
    }

}

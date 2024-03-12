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

    mapping (address => bool) public allowedContracts;

    /**
     * @dev This function is called before the execution of a transaction.
     * It checks that the sender is an EOA or an approved contract.
     *
     * @param sender The address of the contract that is calling the consumer.
     */
    function preExecution(address, address sender, bytes calldata, uint) external view override {
        require(sender == tx.origin || allowedContracts[sender], "ONLY EOA");
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It does nothing in this policy.
     */
    function postExecution(address, address, bytes calldata, uint) external override {}

    /**
     * @dev This function is called to set the allowed status of a contract.
     * This is useful for white-listing contracts that need to call the consumer.
     *
     * @param contractAddress The address of the contract to set the allowed status for.
     * @param status The allowed status to set.
     */
    function setAllowedContracts(address contractAddress, bool status) external onlyRole(POLICY_ADMIN_ROLE) {
        allowedContracts[contractAddress] = status;
    }

}

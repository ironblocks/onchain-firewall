// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "./FirewallPolicyBase.sol";

/**
 * @dev This policy is simply the equivalent of the standard `nonReentrant` modifier.
 *
 * This is much less gas efficient than the `nonReentrant` modifier, but allows consumers to make
 * a non upgradeable contracts method `nonReentrant` post deployment.
 *
 */
contract NonReentrantPolicy is FirewallPolicyBase {

    // consumer => bool
    mapping (address => bool) public hasEnteredConsumer;

    constructor(address _firewallAddress) FirewallPolicyBase() {
        authorizedExecutors[_firewallAddress] = true;
    }

    /**
     * @dev This function is called before the execution of a transaction.
     * It checks that the consumer is not currently executing a transaction.
     *
     * @param consumer The address of the contract that is being called.
     */
    function preExecution(address consumer, address, bytes calldata, uint) external isAuthorized(consumer) {
        require(!hasEnteredConsumer[consumer], "NO REENTRANCY");
        hasEnteredConsumer[consumer] = true;
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It sets the consumer as not currently executing a transaction.
     *
     * @param consumer The address of the contract that is being called.
     */
    function postExecution(address consumer, address, bytes calldata, uint) external isAuthorized(consumer) {
        hasEnteredConsumer[consumer] = false;
    }

}

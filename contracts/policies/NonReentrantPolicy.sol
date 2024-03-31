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
 * NOTE: This policy DOES NOT support Firewall Consumers that call themselves internally, as that would
 * be detected by this policy as a reentrancy attack - causing the transaction to revert.
 *
 * Advanced configuration using multiple instances of this policy can be used to support this use case.
 *
 * If you have any questions on how or when to use this policy, please refer to the Firewall's documentation
 * and/or contact our support.
 *
 */
contract NonReentrantPolicy is FirewallPolicyBase {

    mapping (address => bool) public hasEnteredConsumer;

    constructor(address _firewallAddress) FirewallPolicyBase() {
        authorizedExecutors[_firewallAddress] = true;
    }

    function preExecution(address consumer, address, bytes calldata, uint) external isAuthorized(consumer) {
        require(!hasEnteredConsumer[consumer], "NO REENTRANCY");
        hasEnteredConsumer[consumer] = true;
    }

    function postExecution(address consumer, address, bytes calldata, uint) external isAuthorized(consumer) {
        hasEnteredConsumer[consumer] = false;
    }

}

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

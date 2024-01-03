// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "../interfaces/IFirewallPolicy.sol";

contract NonReentrantPolicy is IFirewallPolicy {

    mapping (address => bool) public hasEnteredConsumer;

    function preExecution(address consumer, address, bytes calldata, uint) external override {
        require(!hasEnteredConsumer[consumer], "NO REENTRANCY");
        hasEnteredConsumer[consumer] = true;
    }

    function postExecution(address consumer, address, bytes calldata, uint) external override {
        hasEnteredConsumer[consumer] = false;
    }
}

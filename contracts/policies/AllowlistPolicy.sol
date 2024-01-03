// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFirewallPolicy.sol";

contract AllowlistPolicy is IFirewallPolicy, Ownable {

    mapping (address => mapping (address => bool)) public consumerAllowlist;

    function preExecution(address consumer, address sender, bytes calldata, uint) external view override {
        require(consumerAllowlist[consumer][sender], "AllowlistPolicy: Sender not allowed");
    }

    function postExecution(address, address, bytes calldata, uint) external override {
        // Do nothing
    }

    function setConsumerAllowlist(address consumer, address account, bool status) external onlyOwner {
        consumerAllowlist[consumer][account] = status;
    }
}

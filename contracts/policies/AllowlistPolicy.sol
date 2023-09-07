// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

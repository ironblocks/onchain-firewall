// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFirewallPolicy {
    function preExecution(address consumer, address sender, bytes memory data, uint value) external;
    function postExecution(address consumer, address sender, bytes memory data, uint value) external;
}

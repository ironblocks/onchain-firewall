// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFirewallPolicy.sol";

contract BalanceChangePolicy is IFirewallPolicy, Ownable {

    mapping (address => uint) public consumerMaxBalanceChange;
    mapping (address => uint) public consumerLastBalance;

    function preExecution(address consumer, address, bytes memory, uint value) external override {
        consumerLastBalance[consumer] = address(consumer).balance - value;
    }

    function postExecution(address consumer, address, bytes memory, uint) external view override {
        uint lastBalance = consumerLastBalance[consumer];
        uint currentBalance = address(consumer).balance;
        uint difference = currentBalance >= lastBalance ? currentBalance - lastBalance : lastBalance - currentBalance;
        require(difference <= consumerMaxBalanceChange[consumer], "BalanceChangePolicy: Balance change exceeds limit");
    }

    function setConsumerMaxBalanceChange(address consumer, uint maxBalanceChange) external onlyOwner {
        consumerMaxBalanceChange[consumer] = maxBalanceChange;
    }
}

// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "../FirewallConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// Demo contract for reentrancy protection.
contract TotallySafeContract is Ownable, FirewallConsumerBase {

    mapping (address => uint) public deposits;

    constructor(address firewall) FirewallConsumerBase(firewall, msg.sender) {}

    function deposit() external payable firewallProtected {
        deposits[msg.sender] += msg.value;
    }

    function withdrawAll() external firewallProtected {
        uint amount = deposits[msg.sender];
        Address.sendValue(payable(msg.sender), amount);
        deposits[msg.sender] = 0;
    }
}


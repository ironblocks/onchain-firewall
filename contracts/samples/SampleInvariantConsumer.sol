// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "../FirewallConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SampleInvariantConsumer is FirewallConsumerBase {

    uint256 private value1;
    uint256 private value2;
    uint256 private value3;

    constructor(address firewall) FirewallConsumerBase(firewall, msg.sender) {}

    function setValue(uint256 newValue) external firewallProtected invariantProtected {
        value1 = newValue;        
    }

    function setMultipleValues(uint256 newValue2, uint256 newValue3) external firewallProtected invariantProtected {
        value2 = newValue2;        
        value3 = newValue3;        
    }

}


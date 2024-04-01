// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import {FirewallConsumerBase} from "../FirewallConsumerBase.sol";

contract SampleInvariantConsumer is FirewallConsumerBase {

    uint private value1;
    uint private value2;
    uint private value3;

    constructor(address firewall) FirewallConsumerBase(firewall, msg.sender) {}

    function setValue(uint newValue) external firewallProtected invariantProtected {
        value1 = newValue;        
    }

    function setMultipleValues(uint newValue2, uint newValue3) external firewallProtected invariantProtected {
        value2 = newValue2;        
        value3 = newValue3;        
    }

}


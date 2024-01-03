// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFirewallPolicy.sol";

contract OnlyEOAPolicy is IFirewallPolicy, Ownable {

    // In case a protocol has e.g two separate contracts both allowing only EOAs but
    // these contracts can also call each other.
    mapping (address => bool) public allowedContracts;

    function preExecution(address, address sender, bytes calldata, uint) external view override {
        require(sender == tx.origin || allowedContracts[sender], "ONLY EOA");
    }

    function postExecution(address, address, bytes calldata, uint) external override {}

    function setAllowedContracts(address contractAddress, bool status) external onlyOwner {
        allowedContracts[contractAddress] = status;
    }

}

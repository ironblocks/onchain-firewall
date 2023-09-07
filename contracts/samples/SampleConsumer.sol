// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IFirewall.sol";
import "../FirewallConsumer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract SampleConsumer is Ownable, FirewallConsumer {

    mapping (address => uint) public deposits;

    constructor(address firewall) FirewallConsumer(firewall, msg.sender) {}

    function deposit() external payable firewallProtected {
        deposits[msg.sender] += msg.value;
    }

    function withdraw(uint amount) external firewallProtected {
        deposits[msg.sender] -= amount;
        Address.sendValue(payable(msg.sender), amount);
    }

    function setOwner(address newOwner) external onlyOwner firewallProtected {
        _transferOwnership(newOwner);
    }

}


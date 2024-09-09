// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {FirewallConsumerBase} from "../FirewallConsumerBase.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SampleConsumer is Ownable, FirewallConsumerBase {

    mapping (address user => uint256 ethBalance) public deposits;
    mapping (address user => mapping (address token => uint256 tokenBalance)) public tokenDeposits;

    constructor(address firewall) FirewallConsumerBase(firewall, msg.sender) {}

    function deposit() external payable firewallProtected {
        deposits[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external firewallProtected {
        deposits[msg.sender] -= amount;
        Address.sendValue(payable(msg.sender), amount);
    }

    function depositToken(address token, uint256 amount) external firewallProtected {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        tokenDeposits[token][msg.sender] += amount;
    }

    function withdrawToken(address token, uint256 amount) external firewallProtected {
        tokenDeposits[token][msg.sender] -= amount;
        IERC20(token).transfer(msg.sender, amount);
    }

    function setOwner(address newOwner) external onlyOwner firewallProtected {
        _transferOwnership(newOwner);
    }

}


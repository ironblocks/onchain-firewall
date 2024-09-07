// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2024
pragma solidity ^0.8.0;

import {SimpleUpgradeableFirewallConsumer, IFirewallConsumerStorage} from "../consumers/SimpleUpgradeableFirewallConsumer.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SampleSimpleConsumerUpgradeable is OwnableUpgradeable, SimpleUpgradeableFirewallConsumer {

    mapping (address user => uint256 ethBalance) public deposits;
    mapping (address user => mapping (address token => uint256 tokenBalance)) public tokenDeposits;

    function initialize(address _consumerStorage) external initializer {
        __Ownable_init();
        __SimpleUpgradeableFirewallConsumer_init(IFirewallConsumerStorage(_consumerStorage), address(0));
    }

    function deposit() external payable firewallProtected {
        deposits[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external payable firewallProtected { 
        deposits[msg.sender] -= amount;
        Address.sendValue(payable(msg.sender), amount);
    }

    function depositToken(address token, uint256 amount) external payable firewallProtected {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        tokenDeposits[token][msg.sender] += amount;
    }

    function withdrawToken(address token, uint256 amount) external payable firewallProtected {
        tokenDeposits[token][msg.sender] -= amount;
        IERC20(token).transfer(msg.sender, amount);
    }


    function setOwner(address newOwner) external onlyOwner firewallProtected {
        _transferOwnership(newOwner);
    }

}

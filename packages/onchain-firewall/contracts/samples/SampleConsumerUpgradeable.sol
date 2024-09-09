// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8;

import {OwnableUpgradeable} from "../../lib/openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Address} from "../../lib/openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "../../lib/openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SampleConsumerUpgradeable is OwnableUpgradeable {

    mapping (address user => uint256 ethBalance) public deposits;
    mapping (address user => mapping (address token => uint256 tokenBalance)) public tokenDeposits;

    function initialize() external initializer {
        __Ownable_init();
    }

    function deposit() external payable {
        deposits[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        deposits[msg.sender] -= amount;
        Address.sendValue(payable(msg.sender), amount);
    }

    function depositToken(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        tokenDeposits[token][msg.sender] += amount;
    }

    function withdrawToken(address token, uint256 amount) external {
        tokenDeposits[token][msg.sender] -= amount;
        IERC20(token).transfer(msg.sender, amount);
    }


    function setOwner(address newOwner) external onlyOwner {
        _transferOwnership(newOwner);
    }

}

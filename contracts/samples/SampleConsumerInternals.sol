// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "../FirewallConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SampleConsumerInternals is Ownable, FirewallConsumerBase {

    mapping (address => uint256) public deposits;
    mapping (address => mapping (address => uint256)) public tokenDeposits;

    constructor(address firewall) FirewallConsumerBase(firewall, msg.sender) {}

    function deposit() external payable firewallProtected {
        _deposit(msg.value);
    }

    function _deposit(uint256 amount) internal firewallProtectedSig(0x9213b124) {
        deposits[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external firewallProtected {
        _withdraw(amount);
    }

    function withdrawMany(uint256 amounts, uint256 times) external firewallProtected {
        for (uint256 i = 0; i < times; i++) {
            _withdraw(amounts);
        }
    }

    function _withdraw(uint256 amount) internal firewallProtectedSig(0xac6a2b5d) {
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


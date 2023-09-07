// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract SampleConsumerUpgradeable is OwnableUpgradeable {

    mapping (address => uint) public deposits;

    function initialize() external initializer {
        __Ownable_init();
    }

    function deposit() external payable {
        deposits[msg.sender] += msg.value;
    }

    function withdraw(uint amount) external {
        deposits[msg.sender] -= amount;
        Address.sendValue(payable(msg.sender), amount);
    }

    function setOwner(address newOwner) external onlyOwner {
        _transferOwnership(newOwner);
    }

}


// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFirewallPolicy.sol";

contract ForbiddenMethodsPolicy is IFirewallPolicy, Ownable {

    mapping (address => mapping (bytes4 => bool)) public consumerMethodStatus;
    mapping (bytes32 => bool) public hasEnteredForbiddenMethod;

    function preExecution(address consumer, address, bytes calldata data, uint) external override {
        bytes32 currentContext = keccak256(abi.encodePacked(tx.origin, block.number, tx.gasprice));
        if (consumerMethodStatus[consumer][bytes4(data)]) {
            hasEnteredForbiddenMethod[currentContext] = true;
        }
    }

    function postExecution(address, address, bytes calldata, uint) external view override {
        bytes32 currentContext = keccak256(abi.encodePacked(tx.origin, block.number, tx.gasprice));
        require(!hasEnteredForbiddenMethod[currentContext], "Forbidden method");
    }

    function setConsumerForbiddenMethod(address consumer, bytes4 methodSig, bool status) external onlyOwner {
        consumerMethodStatus[consumer][methodSig] = status;
    }

}

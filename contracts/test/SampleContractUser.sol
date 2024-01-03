// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "../samples/SampleConsumer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract SampleContractUser {

    function deposit(address sampleConsumer) external payable {
        SampleConsumer(sampleConsumer).deposit{value: msg.value}();
    }

    function withdraw(address sampleConsumer, uint amount) external {
        SampleConsumer(sampleConsumer).withdraw(amount);
    }

    function depositAndWithdraw(address sampleConsumer) external payable {
        SampleConsumer(sampleConsumer).deposit{value: msg.value}();
        SampleConsumer(sampleConsumer).withdraw(msg.value);
    }

    function depositAndWithdrawAndDeposit(address sampleConsumer) external payable {
        SampleConsumer(sampleConsumer).deposit{value: msg.value}();
        SampleConsumer(sampleConsumer).withdraw(msg.value);
        SampleConsumer(sampleConsumer).deposit{value: msg.value}();
    }

    receive() external payable {}
}


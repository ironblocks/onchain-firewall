// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8;

import {SampleConsumer} from "../samples/SampleConsumer.sol";
import {Ownable} from "../../lib/openzeppelin/contracts/access/Ownable.sol";
import {Address} from "../../lib/openzeppelin/contracts/utils/Address.sol";

contract SampleContractUser {

    function deposit(address sampleConsumer) external payable {
        SampleConsumer(sampleConsumer).deposit{value: msg.value}();
    }

    function withdraw(address sampleConsumer, uint256 amount) external {
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

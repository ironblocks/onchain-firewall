// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "../interfaces/IInvariantLogic.sol";

contract SampleInvariantLogic is IInvariantLogic {

    function assertInvariants(
        address consumer,
        bytes4 sighash,
        bytes32[] calldata preValues,
        bytes32[] calldata postValues
    ) external {
        if (sighash == 0x55241077) {
            uint previousValue = uint(preValues[0]);
            uint postValue = uint(postValues[0]);
            require(postValue > previousValue, "INVARIANT1");
        } else if (sighash == 0x320605a8) {
            uint postValue1 = uint(postValues[0]);
            uint postValue2 = uint(postValues[1]);
            require(postValue2 >= postValue1 && postValue2 - postValue1 <= 50, "INVARIANT2");
        }
    }

}


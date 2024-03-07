// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFirewallPrivateInvariantsPolicy.sol";

contract SamplePrivateInvariantsPolicy is IFirewallPrivateInvariantsPolicy, Ownable {

    mapping (address => mapping(bytes4 => bytes32[])) public sighashInvariantStorageSlots;

    function preExecution(
        address consumer,
        address, // We could use data, but for our simple example we dont
        bytes calldata data,
        uint
    ) external view override returns (bytes32[] memory) { 
        bytes32[] memory storageSlots = sighashInvariantStorageSlots[consumer][bytes4(data)];
        return storageSlots;
    }

    function postExecution(
        address,
        address,
        bytes memory data,
        uint,
        bytes32[] calldata preValues,
        bytes32[] calldata postValues
    ) external pure {
        bytes4 sighash = bytes4(data);
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

    function setSighashInvariantStorageSlots(address consumer, bytes4 sighash, bytes32[] calldata storageSlots) external onlyOwner {
        sighashInvariantStorageSlots[consumer][sighash] = storageSlots;
    }

}
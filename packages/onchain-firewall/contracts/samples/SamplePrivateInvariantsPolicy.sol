// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IFirewallPrivateInvariantsPolicy} from "../interfaces/IFirewallPrivateInvariantsPolicy.sol";

contract SamplePrivateInvariantsPolicy is IFirewallPrivateInvariantsPolicy, Ownable {

    mapping (address consumer => mapping(bytes4 sighash => bytes32[] storageSlots)) public sighashInvariantStorageSlots;

    function preExecution(
        address consumer,
        address, // We could use data, but for our simple example we dont
        bytes calldata data,
        uint256
    ) external view override returns (bytes32[] memory) { 
        bytes32[] memory storageSlots = sighashInvariantStorageSlots[consumer][bytes4(data)];
        return storageSlots;
    }

    function postExecution(
        address,
        address,
        bytes memory data,
        uint256,
        bytes32[] calldata preValues,
        bytes32[] calldata postValues
    ) external pure {
        bytes4 sighash = bytes4(data);
        if (sighash == 0x55241077) {
            uint256 previousValue = uint256(preValues[0]);
            uint256 postValue = uint256(postValues[0]);
            require(postValue > previousValue, "INVARIANT1");
        } else if (sighash == 0x320605a8) {
            uint256 postValue1 = uint256(postValues[0]);
            uint256 postValue2 = uint256(postValues[1]);
            require(postValue2 >= postValue1 && postValue2 - postValue1 <= 50, "INVARIANT2");
        }
    }

    function setSighashInvariantStorageSlots(address consumer, bytes4 sighash, bytes32[] calldata storageSlots) external onlyOwner {
        sighashInvariantStorageSlots[consumer][sighash] = storageSlots;
    }

}

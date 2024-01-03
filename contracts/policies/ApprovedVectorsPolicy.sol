// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFirewallPolicy.sol";

contract ApprovedVectorsPolicy is IFirewallPolicy, Ownable {

    // Execution state
    mapping (address => mapping(uint => bytes)) public originCurrentVector;
    mapping (bytes32 => bool) public approvedVectorHashes;

    function preExecution(address, address, bytes calldata data, uint) external override {
        bytes memory currentVector = originCurrentVector[tx.origin][block.number];
        bytes4 selector = bytes4(data);
        bytes memory newVector = abi.encodePacked(currentVector, selector);
        bytes32 newVectorHash = keccak256(newVector);
        // Either this is the first transaction in which case we approve all vectors of length 1 by default,
        // or it must be an approved series of function calls
        require(currentVector.length == 0 || approvedVectorHashes[newVectorHash], "ApprovedVectorsPolicy: Unapproved Vector");
        originCurrentVector[tx.origin][block.number] = newVector;
    }

    function postExecution(address, address, bytes calldata, uint) external override {
    }


    function approveMultipleHashes(bytes32[] calldata _vectorHashes) external onlyOwner {
        for (uint i = 0; i < _vectorHashes.length; i++) {
            approvedVectorHashes[_vectorHashes[i]] = true;
        }
    }

    function removeMultipleHashes(bytes32[] calldata _vectorHashes) external onlyOwner {
        for (uint i = 0; i < _vectorHashes.length; i++) {
            approvedVectorHashes[_vectorHashes[i]] = false;
        }
    }

    function setVectorHashStatus(bytes32 _vectorHash, bool _status) external onlyOwner {
        approvedVectorHashes[_vectorHash] = _status;
    }

}

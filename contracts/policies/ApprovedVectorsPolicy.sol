// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import {FirewallPolicyBase} from "./FirewallPolicyBase.sol";

/**
 * @dev This policy requires a transaction to follow a pre-approved pattern of external and/or internal calls
 * to a protocol or set of contracts.
 *
 * This policy is useful for contracts that want to protect against zero day business logic exploits. By pre
 * approving a large and tested amount of known and approved "vectors" or "patterns", a protocol can allow
 * the vast majority of transactions to pass without requiring any type asynchronous approval mechanism.
 *
 */
contract ApprovedVectorsPolicy is FirewallPolicyBase {

    // Execution state
    mapping (address => mapping(uint => bytes32)) public originCurrentVectorHash;
    mapping (bytes32 => bool) public approvedVectorHashes;

    constructor(address _firewallAddress) FirewallPolicyBase() {
        authorizedExecutors[_firewallAddress] = true;
    }

    function preExecution(address consumer, address, bytes calldata data, uint) external isAuthorized(consumer) {
        bytes32 currentVectorHash = originCurrentVectorHash[tx.origin][block.number];
        bytes4 selector = bytes4(data);
        bytes32 newVectorHash = keccak256(abi.encodePacked(currentVectorHash, selector));
        require(approvedVectorHashes[newVectorHash], "ApprovedVectorsPolicy: Unapproved Vector");
        originCurrentVectorHash[tx.origin][block.number] = newVectorHash;
    }

    function postExecution(address, address, bytes calldata, uint) external override {
    }


    function approveMultipleHashes(bytes32[] calldata _vectorHashes) external onlyRole(POLICY_ADMIN_ROLE) {
        for (uint i = 0; i < _vectorHashes.length; i++) {
            approvedVectorHashes[_vectorHashes[i]] = true;
        }
    }

    function removeMultipleHashes(bytes32[] calldata _vectorHashes) external onlyRole(POLICY_ADMIN_ROLE) {
        for (uint i = 0; i < _vectorHashes.length; i++) {
            approvedVectorHashes[_vectorHashes[i]] = false;
        }
    }

    function setVectorHashStatus(bytes32 _vectorHash, bool _status) external onlyRole(POLICY_ADMIN_ROLE) {
        approvedVectorHashes[_vectorHash] = _status;
    }

}

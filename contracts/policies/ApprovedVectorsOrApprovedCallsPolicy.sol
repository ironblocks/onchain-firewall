// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFirewallPolicy.sol";

contract ApprovedVectorsOrApprovedCallsPolicy is IFirewallPolicy, AccessControl {
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");

    // We use this to get the trace as if the tx is approved by overriding the storage slot in the debug trace call
    bytes32 private constant IS_EXECUTING_SIMULATION_SLOT = keccak256("IS_EXECUTING_SIMULATION"); // 0x5240afa92511149d1ea75355dd533487007d2505fa7bfdceab11878262a081b6

    // Execution state
    mapping (address => mapping(uint => bytes)) public originCurrentVector;
    mapping (bytes32 => bool) public approvedVectorHashes;

    // tx.origin => callHashes
    mapping (address => bytes32[]) public approvedCalls;
    // tx.origin => blockNum => bool
    mapping (address => mapping (uint => bool)) public isOriginUsingApprovedCalls;
    // tx.origin => time of approved calls
    mapping (address => uint256) public approvedCallsExpiration;
    // tx.origin => nonce
    mapping (address => uint256) public nonces;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function preExecution(address consumer, address sender, bytes calldata data, uint value) external override {
        bytes32[] storage approvedCallHashes = approvedCalls[tx.origin];
        if (isOriginUsingApprovedCalls[tx.origin][block.number]) {
            require(approvedCallHashes.length > 0, "ApprovedVectorsOrApprovedCallsPolicy: call hashes empty");
            uint expiration = approvedCallsExpiration[tx.origin];
            require(expiration > block.timestamp, "ApprovedVectorsOrApprovedCallsPolicy: expired");
            bytes32 callHash = getCallHash(consumer, sender, tx.origin, data, value);
            bytes32 nextHash = approvedCallHashes[approvedCallHashes.length - 1];
            require(callHash == nextHash, "ApprovedVectorsOrApprovedCallsPolicy: invalid call hash");
            approvedCallHashes.pop();
        } else if (approvedCallHashes.length > 0) {
            isOriginUsingApprovedCalls[tx.origin][block.number] = true;
            uint expiration = approvedCallsExpiration[tx.origin];
            require(expiration > block.timestamp, "ApprovedVectorsOrApprovedCallsPolicy: expired");
            bytes32 callHash = getCallHash(consumer, sender, tx.origin, data, value);
            bytes32 nextHash = approvedCallHashes[approvedCallHashes.length - 1];
            require(callHash == nextHash, "ApprovedVectorsOrApprovedCallsPolicy: invalid call hash");
            approvedCallHashes.pop();
        } else {
            bytes memory currentVector = originCurrentVector[tx.origin][block.number];
            bytes4 selector = bytes4(data);
            bytes memory newVector = abi.encodePacked(currentVector, selector);
            bytes32 newVectorHash = keccak256(newVector);
            // Either this is the first transaction in which case we approve all vectors of length 1 by default,
            // or it must be an approved series of function calls
            require(currentVector.length == 0 || approvedVectorHashes[newVectorHash], "ApprovedVectorsOrApprovedCallsPolicy: Unapproved Vector");
            originCurrentVector[tx.origin][block.number] = newVector;
        }
    }

    function postExecution(address, address, bytes calldata, uint) external override {
    }

    function approveMultipleHashes(bytes32[] calldata _vectorHashes) external onlyRole(APPROVER_ROLE) {
        for (uint i = 0; i < _vectorHashes.length; i++) {
            approvedVectorHashes[_vectorHashes[i]] = true;
        }
    }

    function removeMultipleHashes(bytes32[] calldata _vectorHashes) external onlyRole(APPROVER_ROLE) {
        for (uint i = 0; i < _vectorHashes.length; i++) {
            approvedVectorHashes[_vectorHashes[i]] = false;
        }
    }

    function setVectorHashStatus(bytes32 _vectorHash, bool _status) external onlyRole(APPROVER_ROLE) {
        approvedVectorHashes[_vectorHash] = _status;
    }

    function approveCalls(
        bytes32[] calldata _callHashes,
        uint256 expiration,
        address txOrigin
    ) external onlyRole(SIGNER_ROLE) {
        approvedCalls[txOrigin] = _callHashes;
        approvedCallsExpiration[txOrigin] = expiration;
    }

    function getCallHash(
        address consumer,
        address sender,
        address origin,
        bytes memory data,
        uint value
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(consumer, sender, origin, data, value));
    }

    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
            );
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }

    function _is_executing_simulation() private view returns (bool is_executing_simulation) {
        bytes32 is_executing_simulation_slot = IS_EXECUTING_SIMULATION_SLOT;
        assembly {
            is_executing_simulation := sload(is_executing_simulation_slot)
        }
    }
}

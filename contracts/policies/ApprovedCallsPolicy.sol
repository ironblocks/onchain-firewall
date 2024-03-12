// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "./FirewallPolicyBase.sol";

/**
 * @dev This policy requires a transaction to a consumer to be signed and approved on chain before execution.
 *
 * This works by approving the ordered sequence of calls that must be made, and then asserting at each step
 * that the next call is as expected. Note that this doesn't assert that the entire sequence is executed.
 *
 */
contract ApprovedCallsPolicy is FirewallPolicyBase {
    // The role that is allowed to approve calls
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    // We use this to get the trace as if the tx is approved by overriding the storage slot in the debug trace call
    bytes32 private constant IS_EXECUTING_SIMULATION_SLOT = keccak256("IS_EXECUTING_SIMULATION"); // 0x5240afa92511149d1ea75355dd533487007d2505fa7bfdceab11878262a081b6

    // tx.origin => callHashes
    mapping (address => bytes32[]) public approvedCalls;
    // tx.origin => time of approved calls
    mapping (address => uint256) public approvedCallsExpiration;
    // tx.origin => nonce
    mapping (address => uint256) public nonces;

    constructor(address _firewallAddress) FirewallPolicyBase() {
        authorizedExecutors[_firewallAddress] = true;
    }

    /**
     * @dev This modifier checks if the contract is currently executing a simulation.
     */
    modifier notInSimulation() {
        if (_is_executing_simulation()) return;
        _;
    }

    /**
     * @dev Before executing a call, check that the call has been approved by a signer.
     *
     * @param consumer The address of the contract that is being called.
     * @param sender The address of the account that is calling the contract.
     * @param data The data that is being sent to the contract.
     * @param value The amount of value that is being sent to the contract.
     */
    function preExecution(address consumer, address sender, bytes calldata data, uint value) external notInSimulation isAuthorized(consumer) {
        bytes32[] storage approvedCallHashes = approvedCalls[tx.origin];
        require(approvedCallHashes.length > 0, "ApprovedCallsPolicy: call hashes empty");
        uint expiration = approvedCallsExpiration[tx.origin];
        require(expiration > block.timestamp, "ApprovedCallsPolicy: expired");
        bytes32 callHash = getCallHash(consumer, sender, tx.origin, data, value);
        bytes32 nextHash = approvedCallHashes[approvedCallHashes.length - 1];
        require(callHash == nextHash, "ApprovedCallsPolicy: invalid call hash");
        approvedCallHashes.pop();
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It does nothing in this policy.
     */
    function postExecution(address, address, bytes calldata, uint) external override {
    }

    /**
     * @dev Allows anyone to approve a call with a signers signature.
     * @param _callHashes The call hashes to approve.
     * @param expiration The expiration time of these approved calls
     * @param txOrigin The transaction origin of the approved hashes.
     * @param nonce Used to prevent replay attacks.
     * @param signature The signature of the signer with the above parameters.
     */
    function approveCallsViaSignature(
        bytes32[] calldata _callHashes,
        uint256 expiration,
        address txOrigin,
        uint nonce,
        bytes memory signature
    ) external {
        require(nonce == nonces[txOrigin], "ApprovedCallsPolicy: invalid nonce");
        bytes32 messageHash = keccak256(abi.encodePacked(_callHashes, expiration, txOrigin, nonce, block.chainid));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        address signer = recoverSigner(ethSignedMessageHash, signature);
        require(hasRole(SIGNER_ROLE, signer), "ApprovedCallsPolicy: invalid signer");
        approvedCalls[txOrigin] = _callHashes;
        approvedCallsExpiration[txOrigin] = expiration;
        nonces[txOrigin] = nonce + 1;
    }

    /**
     * @dev Allows a signer to approve a call.
     * @param _callHashes The call hashes to approve.
     * @param expiration The expiration time of these approved calls
     * @param txOrigin The transaction origin of the approved hashes.
     */
    function approveCalls(
        bytes32[] calldata _callHashes,
        uint256 expiration,
        address txOrigin
    ) external onlyRole(SIGNER_ROLE) {
        approvedCalls[txOrigin] = _callHashes;
        approvedCallsExpiration[txOrigin] = expiration;
    }

    /**
     * @dev Internal helper function to get the hash of a call.
     *
     * @param consumer The address of the contract that is being called.
     * @param sender The address of the account that is calling the contract.
     * @param origin The address of the account that originated the call.
     * @param data The data that is being sent to the contract.
     * @param value The amount of value that is being sent to the contract.
     * @return The hash of the call.
     */
    function getCallHash(
        address consumer,
        address sender,
        address origin,
        bytes memory data,
        uint value
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(consumer, sender, origin, data, value));
    }

    /**
     * @dev Internal helper function to get a signed hash of a message that has been signed with the Ethereum prefix.
     * @param _messageHash The hash of the message.
     */
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

    /**
     * @dev Internal helper function to recover the signer of a message.
     * @param _ethSignedMessageHash The hash of the message that was signed.
     * @param _signature The signature of the message.
     * @return The address of the signer.
     */
    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    /**
     * @dev Internal helper function to split a signature into its r, s, and v components.
     * @param sig The signature to split.
     * @return r The r component of the signature.
     * @return s The s component of the signature.
     * @return v The v component of the signature.
     */
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

    /**
     * @dev This function is called to set the expiration time for approved call hashes.
     * @return is_executing_simulation The expiration time for approved call hashes.
     */
    function _is_executing_simulation() private view returns (bool is_executing_simulation) {
        bytes32 is_executing_simulation_slot = IS_EXECUTING_SIMULATION_SLOT;
        assembly {
            is_executing_simulation := sload(is_executing_simulation_slot)
        }
    }
}

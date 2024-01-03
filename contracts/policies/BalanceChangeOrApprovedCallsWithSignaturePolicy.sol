// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IFirewallPolicy.sol";

contract BalanceChangeOrApprovedCallsWithSignaturePolicy is IFirewallPolicy, AccessControl {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    // We use this to get the trace as if the tx is approved by overriding the storage slot in the debug trace call
    bytes32 private constant IS_EXECUTING_SIMULATION_SLOT = keccak256("IS_EXECUTING_SIMULATION"); // 0x5240afa92511149d1ea75355dd533487007d2505fa7bfdceab11878262a081b6

    // tx.origin => callHashes
    mapping (address => bytes32[]) public approvedCalls;
    // tx.origin => blockNum => bool
    mapping (address => mapping (uint => bool)) public isOriginUsingApprovedCalls;
    // tx.origin => time of approved calls
    mapping (address => uint256) public approvedCallsExpiration;
    // tx.origin => nonce
    mapping (address => uint256) public nonces;

    // consumer => token => uint
    mapping (address => mapping (address => uint)) public consumerMaxBalanceChange;
    // consumer => token => uint[]
    mapping (address => mapping(address => uint[])) public consumerLastBalance;

    mapping (address => address[]) private _consumerTokens;
    mapping (address => mapping(address => bool)) private _monitoringToken;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier notInSimulation() {
        if (_is_executing_simulation()) return;
        _;
    }

    /**
     * @dev Before executing a call, check that the call has been approved by a signer.
     */
    function preExecution(address consumer, address sender, bytes calldata data, uint value) external notInSimulation override {
        bytes32[] storage approvedCallHashes = approvedCalls[tx.origin];
        if (isOriginUsingApprovedCalls[tx.origin][block.number]) {
            require(approvedCallHashes.length > 0, "ApprovedCallsWithSignaturePolicy: call hashes empty");
            uint expiration = approvedCallsExpiration[tx.origin];
            require(expiration > block.timestamp, "ApprovedCallsWithSignaturePolicy: expired");
            bytes32 callHash = getCallHash(consumer, sender, tx.origin, data, value);
            bytes32 nextHash = approvedCallHashes[approvedCallHashes.length - 1];
            require(callHash == nextHash, "ApprovedCallsWithSignaturePolicy: invalid call hash");
            approvedCallHashes.pop();
        } else if (approvedCallHashes.length > 0) {
            isOriginUsingApprovedCalls[tx.origin][block.number] = true;
            uint expiration = approvedCallsExpiration[tx.origin];
            require(expiration > block.timestamp, "ApprovedCallsWithSignaturePolicy: expired");
            bytes32 callHash = getCallHash(consumer, sender, tx.origin, data, value);
            bytes32 nextHash = approvedCallHashes[approvedCallHashes.length - 1];
            require(callHash == nextHash, "ApprovedCallsWithSignaturePolicy: invalid call hash");
            approvedCallHashes.pop();
        } else {
            address[] memory consumerTokens = _consumerTokens[consumer];
            for (uint i = 0; i < consumerTokens.length; i++) {
                address token = consumerTokens[i];
                uint preBalance = token == ETH ? address(consumer).balance - value : IERC20(token).balanceOf(consumer);
                consumerLastBalance[consumer][token].push(preBalance);
            }
        }
    }

    function postExecution(address consumer, address, bytes calldata, uint) external override {
        if (!isOriginUsingApprovedCalls[tx.origin][block.number]) {
            address[] memory consumerTokens = _consumerTokens[consumer];
            for (uint i = 0; i < consumerTokens.length; i++) {
                address token = consumerTokens[i];
                uint[] storage lastBalanceArray = consumerLastBalance[consumer][token];
                uint lastBalance = lastBalanceArray[lastBalanceArray.length - 1];
                uint postBalance = token == ETH ? address(consumer).balance : IERC20(token).balanceOf(consumer);
                uint difference = postBalance >= lastBalance ? postBalance - lastBalance : lastBalance - postBalance;
                require(difference <= consumerMaxBalanceChange[consumer][token], "BalanceChangePolicy: Balance change exceeds limit");
                lastBalanceArray.pop();
            }
        }
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
        require(nonce == nonces[txOrigin], "ApprovedCallsWithSignaturePolicy: invalid nonce");
        bytes32 messageHash = keccak256(abi.encodePacked(_callHashes, expiration, txOrigin, nonce, block.chainid));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        address signer = recoverSigner(ethSignedMessageHash, signature);
        require(hasRole(SIGNER_ROLE, signer), "ApprovedCallsWithSignaturePolicy: invalid signer");
        approvedCalls[txOrigin] = _callHashes;
        approvedCallsExpiration[txOrigin] = expiration;
        nonces[txOrigin] = nonce + 1;
    }

    function removeToken(
        address consumer,
        address token
    ) external onlyRole(SIGNER_ROLE) {
        address[] storage consumerTokens = _consumerTokens[consumer];
        for (uint i = 0; i < consumerTokens.length; i++) {
            if (token == consumerTokens[i]) {
                consumerTokens[i] = consumerTokens[consumerTokens.length - 1];
                consumerTokens.pop();
                break;
            }
        }
        consumerMaxBalanceChange[consumer][token] = 0;
        _monitoringToken[consumer][token] = false;
    }

    function setConsumerMaxBalanceChange(
        address consumer,
        address token,
        uint maxBalanceChange
    ) external onlyRole(SIGNER_ROLE) {
        consumerMaxBalanceChange[consumer][token] = maxBalanceChange;
        if (!_monitoringToken[consumer][token]) {
            _consumerTokens[consumer].push(token);
            _monitoringToken[consumer][token] = true;
        }
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

    function getConsumerTokens(address consumer) external view returns (address[] memory) {
        return _consumerTokens[consumer];
    }

    function _is_executing_simulation() private view returns (bool is_executing_simulation) {
        bytes32 is_executing_simulation_slot = IS_EXECUTING_SIMULATION_SLOT;
        assembly {
            is_executing_simulation := sload(is_executing_simulation_slot)
        }
    }
}

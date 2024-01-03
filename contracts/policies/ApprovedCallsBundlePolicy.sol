// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFirewallPolicy.sol";

contract ApprovedCallsBundlePolicy is IFirewallPolicy, Ownable {

    // We use this to get the trace as if the tx is approved by overriding the storage slot in the debug trace call
    bytes32 private constant IS_EXECUTING_SIMULATION_SLOT = keccak256("IS_EXECUTING_SIMULATION"); // 0x5240afa92511149d1ea75355dd533487007d2505fa7bfdceab11878262a081b6

    // Execution state
    bytes32[] public callHashes;

    modifier notInSimulation() {
        if (_is_executing_simulation()) return;
        _;
    }

    function preExecution(address consumer, address sender, bytes calldata data, uint value) external notInSimulation override {
        require(callHashes.length > 0, "ApprovedCallsBundlePolicy: call hashes empty");
        bytes32 callHash = getCallHash(consumer, sender, tx.origin, data, value, block.number);
        bytes32 nextHash = callHashes[callHashes.length - 1];
        require(callHash == nextHash, "ApprovedCallsBundlePolicy: invalid call hash");
        callHashes.pop();
    }

    function postExecution(address, address, bytes calldata, uint) external override {
    }

    function approveCalls(bytes32[] calldata _callHashes) external onlyOwner {
        callHashes = _callHashes;
    }

    function getCallHash(
        address consumer,
        address sender,
        address origin,
        bytes memory data,
        uint value,
        uint blockNum
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(consumer, sender, origin, data, value, blockNum));
    }

    function _is_executing_simulation() private view returns (bool is_executing_simulation) {
        bytes32 is_executing_simulation_slot = IS_EXECUTING_SIMULATION_SLOT;
        assembly {
            is_executing_simulation := sload(is_executing_simulation_slot)
        }
    }
}

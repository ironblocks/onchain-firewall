// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFirewallPrivateInvariantsPolicy.sol";
import "../interfaces/IInvariantLogic.sol";

contract PrivateInvariantsPolicy is IFirewallPrivateInvariantsPolicy, Ownable {

    address public invariantLogicContract;
    mapping (address => mapping(bytes4 => bytes32[])) public sighashInvariantStorageSlots;

    function preExecution(
        address consumer,
        address,
        bytes calldata data,
        uint
    ) external view override returns (bytes32[] memory) { 
        bytes32[] memory storageSlots = sighashInvariantStorageSlots[consumer][bytes4(data)];
        return storageSlots;
    }

    function postExecution(
        address consumer,
        address,
        bytes memory data,
        uint,
        bytes32[] calldata preValues,
        bytes32[] calldata postValues
    ) external {
        IInvariantLogic(invariantLogicContract).assertInvariants(
            consumer,
            bytes4(data),
            preValues,
            postValues
        );
    }

    function setSighashInvariantStorageSlots(address consumer, bytes4 sighash, bytes32[] calldata storageSlots) external onlyOwner {
        sighashInvariantStorageSlots[consumer][sighash] = storageSlots;
    }

    function setInvariantLogicContract(address _invariantLogicContract) external onlyOwner {
        invariantLogicContract = _invariantLogicContract;
    }

}

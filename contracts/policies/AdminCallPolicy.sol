// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFirewallPolicy.sol";

/**
 * @dev This contract is a policy which requires a third party to approve any admin calls.
 *
 * This policy is useful for contracts that have sensitive admin functions that need to be called frequently, and you
 * don't necessarily want to use a multisig wallet to call them (although this can also be used on top of a multisig
 * for even better security). You can use this policy to allow a third party to approve the call after off-chain
 * authentication verifying that the owner of the contract is the one making the call.
 *
 */
contract AdminCallPolicy is IFirewallPolicy, Ownable {

    // The default amount of time a call hash is valid for after it is approved.
    uint public expirationTime = 1 days;
    // The timestamp that a call hash was approved at (if approved at all).
    mapping (bytes32 => uint) public adminCallHashApprovalTimestamp;

    function preExecution(address consumer, address sender, bytes calldata data, uint value) external override {
        bytes32 callHash = getCallHash(consumer, sender, tx.origin, data, value);
        require(adminCallHashApprovalTimestamp[callHash] > 0, "AdminCallPolicy: Call not approved");
        require(adminCallHashApprovalTimestamp[callHash] + expirationTime > block.timestamp, "AdminCallPolicy: Call expired");
        adminCallHashApprovalTimestamp[callHash] = 0;
    }

    function postExecution(address, address, bytes calldata, uint) external override {
    }

    function setExpirationTime(uint _expirationTime) external onlyOwner {
        expirationTime = _expirationTime;
    }

    function approveCall(bytes32 _callHash) external onlyOwner {
        adminCallHashApprovalTimestamp[_callHash] = block.timestamp;
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
}
// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFirewallPolicy.sol";

contract CombinedPoliciesPolicy is IFirewallPolicy, Ownable {

    address public firewallAddress;
    bytes32[] public allowedCombinationHashes;
    mapping (bytes32 => bool) public isAllowedCombination;
    // to prevent malicious fake consumers from doing pre and not post
    mapping (address => bool) public approvedConsumer;
    address[] public policies;
    bool[][] public currentResults;

    function preExecution(address consumer, address sender, bytes calldata data, uint value) external override {
        require(msg.sender == firewallAddress, "Only Firewall");
        require(approvedConsumer[consumer], "Only approved consumers");
        bool[] memory currentResult = new bool[](policies.length);
        for (uint i = 0; i < policies.length; i++) {
            IFirewallPolicy policy = IFirewallPolicy(policies[i]);
            try policy.preExecution(consumer, sender, data, value) {
                currentResult[i] = true;
            } catch Error(string memory) {
                // Do nothing
            }
        }
        currentResults.push(currentResult);
    }

    function postExecution(address consumer, address sender, bytes calldata data, uint value) external override {
        require(msg.sender == firewallAddress, "Only Firewall");
        require(approvedConsumer[consumer], "Only approved consumers");
        bool[] memory currentResult = currentResults[currentResults.length - 1];
        currentResults.pop();
        for (uint i = 0; i < policies.length; i++) {
            IFirewallPolicy policy = IFirewallPolicy(policies[i]);
            try policy.postExecution(consumer, sender, data, value) {
                // Do nothing
            } catch Error(string memory) {
                currentResult[i] = false;
            }
        }
        bytes32 combinationHash = keccak256(abi.encodePacked(currentResult));
        require(isAllowedCombination[combinationHash], "CombinedPoliciesPolicy: Disallowed combination");
    }

    function setConsumersStatuses(address[] calldata consumers, bool[] calldata statuses) external onlyOwner {
        for (uint i = 0; i < consumers.length; i++) {
            approvedConsumer[consumers[i]] = statuses[i];
        }
    }

    function setFirewall(address _firewallAddress) external onlyOwner {
        firewallAddress = _firewallAddress;
    }

    function setAllowedCombinations(address[] calldata _policies, bool[][] calldata _allowedCombinations) external onlyOwner {
        // Reset all combinations to false
        for (uint i = 0; i < allowedCombinationHashes.length; i++) {
            isAllowedCombination[allowedCombinationHashes[i]] = false;
        }
        allowedCombinationHashes = new bytes32[](_allowedCombinations.length);
        // Set all new combinations to true
        for (uint i = 0; i < _allowedCombinations.length; i++) {
            isAllowedCombination[keccak256(abi.encodePacked(_allowedCombinations[i]))] = true;
            allowedCombinationHashes[i] = (keccak256(abi.encodePacked(_allowedCombinations[i])));
        }
        policies = _policies;
    }
}

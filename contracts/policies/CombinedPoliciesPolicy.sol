// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import {FirewallPolicyBase, IFirewallPolicy} from "./FirewallPolicyBase.sol";

/**
 * @dev This policy allows the combining of multiple other policies
 *
 * This policy is useful for consumers that want to combine multiple policies, requiring some
 * combination of them to pass for this policy to pass. Amongst the benefits of this policy are
 * increased security due to not needing to write a custom policy which combines the logic of the
 * desired combinations.
 *
 */
contract CombinedPoliciesPolicy is FirewallPolicyBase {

    bytes32[] public allowedCombinationHashes;
    mapping (bytes32 => bool) public isAllowedCombination;
    address[] public policies;
    bool[][] public currentResults;

    constructor(address _firewallAddress) FirewallPolicyBase() {
        authorizedExecutors[_firewallAddress] = true;
    }

    function preExecution(address consumer, address sender, bytes calldata data, uint value) external isAuthorized(consumer) {
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

    function postExecution(address consumer, address sender, bytes calldata data, uint value) external isAuthorized(consumer) {
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

    function setAllowedCombinations(address[] calldata _policies, bool[][] calldata _allowedCombinations) external onlyRole(POLICY_ADMIN_ROLE) {
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

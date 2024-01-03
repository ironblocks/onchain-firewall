// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IFirewall.sol";
import "./interfaces/IFirewallConsumer.sol";
import "./interfaces/IFirewallPolicy.sol";
import "./interfaces/IFirewallPrivateInvariantsPolicy.sol";

/**
 * @title Firewall
 * @author David Benchimol @ Ironblocks
 * @dev This contract provides an open marketplace of firewall policies that can be subscribed to by consumers.
 *
 * Each policy is a contract that must implement the IFirewallPolicy interface. The policy contract is responsible for
 * making the decision on whether or not to allow a call to be executed. The policy contract gets access to the consumers
 * full context, including the sender, data, and value of the call as well as the ability to read the before and after
 * of the function execution.
 *
 * Each consumer is a contract whos policys are managed by a single admin. The admin is responsible for adding and removing
 * policies.
 */
contract Firewall is IFirewall, Ownable {

    modifier onlyConsumerAdmin(address consumer) {
        require(msg.sender == IFirewallConsumer(consumer).firewallAdmin(), "Firewall: not consumer admin");
        _;
    }

    mapping (address => bool) public approvedPolicies;
    mapping (address => mapping (bytes4 => address[])) public subscribedPolicies;
    mapping (address => address[]) public subscribedGlobalPolicies;

    mapping (address => mapping (bytes4 => address)) public subscribedPrivateInvariantsPolicy;

    /**
     * @dev Runs the preExecution hook of all subscribed policies.
     */
    function preExecution(address sender, bytes calldata data, uint value) external override {
        bytes4 selector = bytes4(data);
        address[] memory policies = subscribedPolicies[msg.sender][selector];
        address[] memory globalPolicies = subscribedGlobalPolicies[msg.sender];
        for (uint i = 0; i < policies.length; i++) {
            IFirewallPolicy(policies[i]).preExecution(msg.sender, sender, data, value);
        }
        for (uint i = 0; i < globalPolicies.length; i++) {
            IFirewallPolicy(globalPolicies[i]).preExecution(msg.sender, sender, data, value);
        }
    }

    /**
     * @dev Runs the postExecution hook of all subscribed policies.
     */
    function postExecution(address sender, bytes calldata data, uint value) external override {
        bytes4 selector = bytes4(data);
        address[] memory policies = subscribedPolicies[msg.sender][selector];
        address[] memory globalPolicies = subscribedGlobalPolicies[msg.sender];
        for (uint i = 0; i < policies.length; i++) {
            IFirewallPolicy(policies[i]).postExecution(msg.sender, sender, data, value);
        }
        for (uint i = 0; i < globalPolicies.length; i++) {
            IFirewallPolicy(globalPolicies[i]).postExecution(msg.sender, sender, data, value);
        }
    }


    /**
     * @dev Runs the preExecution hook of all subscribed policies along with private variables policy
     */
    function preExecutionPrivateInvariants(
        address sender,
        bytes calldata data,
        uint value
    ) external override returns (bytes32[] memory storageSlots) {
        bytes4 selector = bytes4(data);
        address privateInvariantsPolicy = subscribedPrivateInvariantsPolicy[msg.sender][selector];
        if (privateInvariantsPolicy != address(0)) {
            storageSlots = IFirewallPrivateInvariantsPolicy(privateInvariantsPolicy).preExecution(msg.sender, sender, data, value);
        }
    }

    /**
     * @dev Runs the postExecution hook of all subscribed policies along with private variables policy
     */
    function postExecutionPrivateInvariants(
        address sender,
        bytes memory data,
        uint value,
        bytes32[] calldata preValues,
        bytes32[] calldata postValues
    ) external override {
        bytes4 selector = bytes4(data);
        address privateInvariantsPolicy = subscribedPrivateInvariantsPolicy[msg.sender][selector];
        if (privateInvariantsPolicy != address(0)) {
            IFirewallPrivateInvariantsPolicy(privateInvariantsPolicy).postExecution(msg.sender, sender, data, value, preValues, postValues);
        }
    }

    /**
     * @dev Owner only function allowing the owner to approve or remove a policy contract. This allows the policy
     * to be subscribed to by consumers, or conversely no longer be allowed.
     */
    function setPolicyStatus(address policy, bool status) external onlyOwner {
        approvedPolicies[policy] = status;
    }

    /**
     * @dev Admin only function allowing the consumers admin to add a policy to the consumers subscribed policies.
     */
    function addGlobalPolicy(address consumer, address policy) external onlyConsumerAdmin(consumer) {
        _addGlobalPolicy(consumer, policy);
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove a policy from the consumers subscribed policies.
     */
    function removeGlobalPolicy(address consumer, address policy) external onlyConsumerAdmin(consumer) {
        _removeGlobalPolicy(consumer, policy);
    }

    /**
     * @dev Admin only function allowing the consumers admin to add a single policy to multiple consumers.
     * Note that the consumer admin needs to be the same for all consumers
     */
    function addGlobalPolicyForConsumers(address[] calldata consumers, address policy) external {
        for (uint i = 0; i < consumers.length; i++) {
            require(msg.sender == IFirewallConsumer(consumers[i]).firewallAdmin(), "Firewall: not consumer admin");
            _addGlobalPolicy(consumers[i], policy);
        }
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove a single policy from multiple consumers.
     * Note that the consumer admin needs to be the same for all consumers
     */
    function removeGlobalPolicyForConsumers(address[] calldata consumers, address policy) external {
        for (uint i = 0; i < consumers.length; i++) {
            require(msg.sender == IFirewallConsumer(consumers[i]).firewallAdmin(), "Firewall: not consumer admin");
            _removeGlobalPolicy(consumers[i], policy);
        }
    }

    /**
     * @dev Admin only function allowing the consumers admin to add multiple policies to the consumers subscribed policies.
     */
    function addPolicies(address consumer, bytes4[] calldata methodSigs, address[] calldata policies) external onlyConsumerAdmin(consumer) {
        for (uint i = 0; i < policies.length; i++) {
            _addPolicy(consumer, methodSigs[i], policies[i]);
        }
    }

    /**
     * @dev Admin only function allowing the consumers admin to add a policy to the consumers subscribed policies.
     */
    function addPolicy(address consumer, bytes4 methodSig, address policy) external onlyConsumerAdmin(consumer) {
        _addPolicy(consumer, methodSig, policy);
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove multiple policies from the consumers subscribed policies.
     */
    function removePolicies(address consumer, bytes4[] calldata methodSigs, address[] calldata policies) external onlyConsumerAdmin(consumer) {
        for (uint i = 0; i < policies.length; i++) {
            _removePolicy(consumer, methodSigs[i], policies[i]);
        }
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove a policy from the consumers subscribed policies.
     */
    function removePolicy(address consumer, bytes4 methodSig, address policy) external onlyConsumerAdmin(consumer) {
        _removePolicy(consumer, methodSig, policy);
    }

    /**
     * @dev Admin only function allowing the consumers admin to set the private variables policies
     */
    function setPrivateInvariantsPolicy(address consumer, bytes4[] calldata methodSigs, address[] calldata policies) external onlyConsumerAdmin(consumer) {
        for (uint i = 0; i < policies.length; i++) {
            require(approvedPolicies[policies[i]], "Firewall: policy not approved");
            subscribedPrivateInvariantsPolicy[consumer][methodSigs[i]] = policies[i];
        }
    }

    /**
     * @dev View function for retrieving a consumers subscribed policies for a given method.
     */
    function getActivePolicies(address consumer, bytes4 methodSig) external view returns (address[] memory) {
        return subscribedPolicies[consumer][methodSig];
    }

    /**
     * @dev View function for retrieving a consumers subscribed global policies.
     */
    function getActiveGlobalPolicies(address consumer) external view returns (address[] memory) {
        return subscribedGlobalPolicies[consumer];
    }

    function _addPolicy(address consumer, bytes4 methodSig, address policy) internal {
        require(approvedPolicies[policy], "Firewall: policy not approved");
        address[] memory policies = subscribedPolicies[consumer][methodSig];
        for (uint i = 0; i < policies.length; i++) {
            require(policy != policies[i], "Firewall: policy already exists");
        }
        subscribedPolicies[consumer][methodSig].push(policy);
    }

    function _removePolicy(address consumer, bytes4 methodSig, address policy) internal {
        address[] storage policies = subscribedPolicies[consumer][methodSig];
        for (uint i = 0; i < policies.length; i++) {
            if (policy == policies[i]) {
                policies[i] = policies[policies.length - 1];
                policies.pop();
                return;
            }
        }
    }

    function _addGlobalPolicy(address consumer, address policy) internal {
        require(approvedPolicies[policy], "Firewall: policy not approved");
        address[] memory policies = subscribedGlobalPolicies[consumer];
        for (uint i = 0; i < policies.length; i++) {
            require(policy != policies[i], "Firewall: policy already exists");
        }
        subscribedGlobalPolicies[consumer].push(policy);
    }

    function _removeGlobalPolicy(address consumer, address policy) internal {
        address[] storage globalPolicies = subscribedGlobalPolicies[consumer];
        for (uint i = 0; i < globalPolicies.length; i++) {
            if (policy == globalPolicies[i]) {
                globalPolicies[i] = globalPolicies[globalPolicies.length - 1];
                globalPolicies.pop();
                return;
            }
        }
    }

}

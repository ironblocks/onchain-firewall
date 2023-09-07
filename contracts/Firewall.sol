// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IFirewall.sol";
import "./interfaces/IFirewallConsumer.sol";
import "./interfaces/IFirewallPolicy.sol";

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
contract Firewall is IFirewall, OwnableUpgradeable {

    modifier onlyConsumerAdmin(address consumer) {
        require(msg.sender == IFirewallConsumer(consumer).firewallAdmin(), "Firewall: not consumer admin");
        _;
    }

    mapping (address => bool) public approvedPolicies;
    mapping (address => mapping (bytes4 => address[])) public subscribedPolicies;
    mapping (address => address[]) public subscribedGlobalPolicies;

    /**
     * @dev Standard ownable upgradeable initializer. This is called once when the contract is deployed.
     */
    function initialize() external initializer {
        __Ownable_init();
    }

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
            IFirewallPolicy(globalPolicies[i]).preExecution(msg.sender, sender, data, value);
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
        require(approvedPolicies[policy], "Firewall: policy not approved");
        address[] memory policies = subscribedGlobalPolicies[consumer];
        for (uint i = 0; i < policies.length; i++) {
            require(policy != policies[i], "Firewall: policy already exists");
        }
        subscribedGlobalPolicies[consumer].push(policy);
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove a policy from the consumers subscribed policies.
     */
    function removeGlobalPolicy(address consumer, uint policyIndex) external onlyConsumerAdmin(consumer) {
        address[] storage globalPolicies = subscribedGlobalPolicies[consumer];
        globalPolicies[policyIndex] = globalPolicies[globalPolicies.length - 1];
        globalPolicies.pop();
    }

    /**
     * @dev Admin only function allowing the consumers admin to add a policy to the consumers subscribed policies.
     */
    function addPolicy(address consumer, bytes4 methodSig, address policy) external onlyConsumerAdmin(consumer) {
        require(approvedPolicies[policy], "Firewall: policy not approved");
        address[] memory policies = subscribedPolicies[consumer][methodSig];
        for (uint i = 0; i < policies.length; i++) {
            require(policy != policies[i], "Firewall: policy already exists");
        }
        subscribedPolicies[consumer][methodSig].push(policy);
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove a policy from the consumers subscribed policies.
     */
    function removePolicy(address consumer, bytes4 methodSig, uint policyIndex) external onlyConsumerAdmin(consumer) {
        address[] storage policies = subscribedPolicies[consumer][methodSig];
        policies[policyIndex] = policies[policies.length - 1];
        policies.pop();
    }

    /**
     * @dev View function for retrieving a consumers subscribed policies for a given method.
     */
    function getActivePolicies(address consumer, bytes4 methodSig) external view returns (address[] memory) {
        return subscribedPolicies[consumer][methodSig];
    }

}

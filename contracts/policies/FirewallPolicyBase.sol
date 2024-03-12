// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IFirewallPolicy.sol";

abstract contract FirewallPolicyBase is IFirewallPolicy, AccessControl {
    bytes32 public constant POLICY_ADMIN_ROLE = keccak256("POLICY_ADMIN_ROLE");

    mapping (address executor => bool authorized) public authorizedExecutors;
    mapping (address consumer => bool approved) public approvedConsumer;

    modifier isAuthorized(address consumer) {
        require(authorizedExecutors[msg.sender], "FirewallPolicy: Only authorized executor");
        require(approvedConsumer[consumer], "FirewallPolicy: Only approved consumers");
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setConsumersStatuses(address[] calldata consumers, bool[] calldata statuses) external onlyRole(POLICY_ADMIN_ROLE) {
        for (uint i = 0; i < consumers.length; i++) {
            approvedConsumer[consumers[i]] = statuses[i];
        }
    }

    function setExecutorStatus(address caller, bool status) external onlyRole(POLICY_ADMIN_ROLE) {
        authorizedExecutors[caller] = status;
    }
}

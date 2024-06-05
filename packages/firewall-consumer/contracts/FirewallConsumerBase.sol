// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2024
pragma solidity ^0.8;

import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "./interfaces/IFirewall.sol";
import "./interfaces/IFirewallConsumer.sol";

/**
 * @title Firewall Consumer Base Contract
 * @author David Benchimol @ Ironblocks
 * @dev This contract is a parent contract that can be used to add firewall protection to any contract.
 *
 * The contract must define a firewall contract which will manage the policies that are applied to the contract.
 * It also must define a firewall admin which will be able to add and remove policies.
 *
 */
contract FirewallConsumerBase is IFirewallConsumer {

    bool private invariantsEnabled;
    address private firewall;
    address public firewallAdmin;

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall, applying each of
     * the subscribed policies.
     */
    modifier firewallProtected() {
        if (firewall == address(0)) {
            _;
            return;
        }
        uint value;
        // We do this because msg.value can only be accessed in payable functions.
        assembly {
            value := callvalue()
        }
        IFirewall(firewall).preExecution(msg.sender, msg.data, value);
        _;
        IFirewall(firewall).postExecution(msg.sender, msg.data, value);
    }

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall, applying each of
     * the subscribed policies. Allows passing custom data to the firewall, not necessarily msg.data.
     * Useful for checking internal function calls
     */
    modifier firewallProtectedCustom(bytes memory data) {
        if (firewall == address(0)) {
            _;
            return;
        }
        uint value;
        // We do this because msg.value can only be accessed in payable functions.
        assembly {
            value := callvalue()
        }
        IFirewall(firewall).preExecution(msg.sender, data, value);
        _;
        IFirewall(firewall).postExecution(msg.sender, data, value);
    }

    /**
     * @dev identical to the rest of the modifiers in terms of logic, but makes it more
     * aesthetic when all you want to pass are signatures/unique identifiers.
     */
    modifier firewallProtectedSig(bytes4 selector) {
        if (firewall == address(0)) {
            _;
            return;
        }
        uint value;
        // We do this because msg.value can only be accessed in payable functions.
        assembly {
            value := callvalue()
        }
        IFirewall(firewall).preExecution(msg.sender, abi.encodePacked(selector), value);
        _;
        IFirewall(firewall).postExecution(msg.sender, abi.encodePacked(selector), value);
    }

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall invariant policy,
     * applying the subscribed invariant policy
     */
    modifier invariantProtected() {
        if (firewall == address(0)) {
            _;
            return;
        }
        uint value;
        // We do this because msg.value can only be accessed in payable functions.
        assembly {
            value := callvalue()
        }
        bytes32[] memory storageSlots = IFirewall(firewall).preExecutionPrivateInvariants(msg.sender, msg.data, value);
        bytes32[] memory preValues = _readStorage(storageSlots);
        _;
        bytes32[] memory postValues = _readStorage(storageSlots);
        IFirewall(firewall).postExecutionPrivateInvariants(msg.sender, msg.data, value, preValues, postValues);
    }

    /**
     * @dev modifier similar to onlyOwner, but for the firewall admin.
     */
    modifier onlyFirewallAdmin() {
        require(msg.sender == firewallAdmin, "FirewallConsumer: not firewall admin");
        _;
    }

    /**
     * @dev Initializes a contract protected by a firewall, with a firewall address and a firewall admin.
     */
    constructor(
        address _firewall,
        address _firewallAdmin
    ) {
        firewall = _firewall;
        firewallAdmin = _firewallAdmin;
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove a policy from the consumers subscribed policies.
     */
    function setFirewall(address _firewall) external onlyFirewallAdmin {
        firewall = _firewall;
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove a policy from the consumers subscribed policies.
     */
    function setFirewallAdmin(address _firewallAdmin) external onlyFirewallAdmin {
        require(_firewallAdmin != address(0), "FirewallConsumer: zero address");
        firewallAdmin = _firewallAdmin;
    }

    function _readStorage(bytes32[] memory storageSlots) internal view returns (bytes32[] memory) {
        uint256 slotsLength = storageSlots.length;
        bytes32[] memory values = new bytes32[](slotsLength);

        for (uint256 i = 0; i < slotsLength; i++) {
            bytes32 slotValue = StorageSlot.getBytes32Slot(storageSlots[i]).value;
            values[i] = slotValue;
        }
        return values;
    }
}

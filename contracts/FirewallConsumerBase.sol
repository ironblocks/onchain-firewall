// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
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
contract FirewallConsumerBase is IFirewallConsumer, Context {

    // This slot is used to store the firewall address
    bytes32 private constant FIREWALL_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall")) - 1);

    // This slot is used to store the firewall admin address
    bytes32 private constant FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall.admin")) - 1);

    // This slot is used to store the new firewall admin address (when changing admin)
    bytes32 private constant NEW_FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.new.firewall.admin")) - 1);

    // This slot is special since it's used for mappings and not a single value
    bytes32 private constant APPROVED_TARGETS_MAPPING_SLOT = bytes32(uint256(keccak256("eip1967.approved.targets")) - 1);

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall, applying each of
     * the subscribed policies.
     */
    modifier firewallProtected() {
        address firewall = _getAddressBySlot(FIREWALL_STORAGE_SLOT);
        if (firewall == address(0)) {
            _;
            return;
        }
        uint value = _msgValue();
        IFirewall(firewall).preExecution(msg.sender, msg.data, value);
        _;
        IFirewall(firewall).postExecution(msg.sender, msg.data, value);
    }

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall, applying each of
     * the subscribed policies. Allows passing custom data to the firewall, not necessarily msg.data.
     * Useful for checking internal function calls
     *
     * @param data custom data to be passed to the firewall
     */
    modifier firewallProtectedCustom(bytes memory data) {
        address firewall = _getAddressBySlot(FIREWALL_STORAGE_SLOT);
        if (firewall == address(0)) {
            _;
            return;
        }
        uint value = _msgValue();
        IFirewall(firewall).preExecution(msg.sender, data, value);
        _;
        IFirewall(firewall).postExecution(msg.sender, data, value);
    }

    /**
     * @dev identical to the rest of the modifiers in terms of logic, but makes it more
     * aesthetic when all you want to pass are signatures/unique identifiers.
     *
     * @param selector unique identifier for the function
     */
    modifier firewallProtectedSig(bytes4 selector) {
        address firewall = _getAddressBySlot(FIREWALL_STORAGE_SLOT);
        if (firewall == address(0)) {
            _;
            return;
        }
        uint value = _msgValue();
        IFirewall(firewall).preExecution(msg.sender, abi.encodePacked(selector), value);
        _;
        IFirewall(firewall).postExecution(msg.sender, abi.encodePacked(selector), value);
    }

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall invariant policy,
     * applying the subscribed invariant policy
     */
    modifier invariantProtected() {
        address firewall = _getAddressBySlot(FIREWALL_STORAGE_SLOT);
        if (firewall == address(0)) {
            _;
            return;
        }
        uint value = _msgValue();
        bytes32[] memory storageSlots = IFirewall(firewall).preExecutionPrivateInvariants(msg.sender, msg.data, value);
        bytes32[] memory preValues = _readStorage(storageSlots);
        _;
        bytes32[] memory postValues = _readStorage(storageSlots);
        IFirewall(firewall).postExecutionPrivateInvariants(msg.sender, msg.data, value, preValues, postValues);
    }


    /**
     * @dev modifier asserting that the target is approved
     * @param target address of the target
     */
    modifier onlyApprovedTarget(address target) {
        // We use the same logic that solidity uses for mapping locations, but we add a pseudorandom
        // constant "salt" instead of a constant placeholder so that there are no storage collisions
        // if adding this to an upgradeable contract implementation
        bytes32 _slot = keccak256(abi.encode(APPROVED_TARGETS_MAPPING_SLOT, target));
        bool isApprovedTarget = _getValueBySlot(_slot) != bytes32(0);
        require(isApprovedTarget, "FirewallConsumer: Not approved target");
        _;
    }

    /**
     * @dev modifier similar to onlyOwner, but for the firewall admin.
     */
    modifier onlyFirewallAdmin() {
        require(msg.sender == _getAddressBySlot(FIREWALL_ADMIN_STORAGE_SLOT), "FirewallConsumer: not firewall admin");
        _;
    }

    /**
     * @dev Initializes a contract protected by a firewall, with a firewall address and a firewall admin.
     */
    constructor(
        address _firewall,
        address _firewallAdmin
    ) {
        _setAddressBySlot(FIREWALL_STORAGE_SLOT, _firewall);
        _setAddressBySlot(FIREWALL_ADMIN_STORAGE_SLOT, _firewallAdmin);
    }

    /**
     * @dev Allows calling an approved external target before executing a method.
     *
     * This can be used for multiple purposes, but the initial one is to call `approveCallsViaSignature` before
     * executing a function, allowing synchronous transaction approvals.
     *
     * @param target address of the target
     * @param targetPayload payload to be sent to the target
     * @param data data to be executed after the target call
     */
    function safeFunctionCall(
        address target,
        bytes calldata targetPayload,
        bytes calldata data
    ) external payable onlyApprovedTarget(target) {
        (bool success, ) = target.call(targetPayload);
        require(success);
        require(msg.sender == _msgSender(), "FirewallConsumer: No meta transactions");
        Address.functionDelegateCall(address(this), data);
    }

    /**
     * @dev Allows firewall admin to set approved targets.
     * IMPORTANT: Only set approved target if you know what you're doing. Anyone can cause this contract
     * to send any data to an approved target.
     *
     * @param target address of the target
     * @param status status of the target
     */
    function setApprovedTarget(address target, bool status) external onlyFirewallAdmin {
        bytes32 _slot = keccak256(abi.encode(APPROVED_TARGETS_MAPPING_SLOT, target));
        assembly {
            sstore(_slot, status)
        }
    }

    /**
     * @dev View function for the firewall admin
     */
    function firewallAdmin() external view returns (address) {
        return _getAddressBySlot(FIREWALL_ADMIN_STORAGE_SLOT);
    }

    /**
     * @dev Admin only function allowing the consumers admin to set the firewall address.
     * @param _firewall address of the firewall
     */
    function setFirewall(address _firewall) external onlyFirewallAdmin {
        _setAddressBySlot(FIREWALL_STORAGE_SLOT, _firewall);
    }

    /**
     * @dev Admin only function, sets new firewall admin. New admin must accept.
     * @param _firewallAdmin address of the new firewall admin
     */
    function setFirewallAdmin(address _firewallAdmin) external onlyFirewallAdmin {
        require(_firewallAdmin != address(0), "FirewallConsumer: zero address");
        _setAddressBySlot(NEW_FIREWALL_ADMIN_STORAGE_SLOT, _firewallAdmin);
    }

    /**
     * @dev Accept the role as firewall admin.
     */
    function acceptFirewallAdmin() external {
        require(msg.sender == _getAddressBySlot(NEW_FIREWALL_ADMIN_STORAGE_SLOT), "FirewallConsumer: not new admin");
        _setAddressBySlot(FIREWALL_ADMIN_STORAGE_SLOT, msg.sender);
    }

    /**
     * @dev Internal helper funtion to get the msg.value
     * @return value of the msg.value
     */
    function _msgValue() internal view returns (uint value) {
        // We do this because msg.value can only be accessed in payable functions.
        assembly {
            value := callvalue()
        }
    }

    /**
     * @dev Internal helper function to read storage slots
     * @param storageSlots array of storage slots
     */
    function _readStorage(bytes32[] memory storageSlots) internal view returns (bytes32[] memory) {
        uint256 slotsLength = storageSlots.length;
        bytes32[] memory values = new bytes32[](slotsLength);

        for (uint256 i = 0; i < slotsLength; i++) {
            bytes32 slotValue = _getValueBySlot(storageSlots[i]);
            values[i] = slotValue;
        }
        return values;
    }

    /**
     * @dev Internal helper function to set an address in a storage slot
     * @param _slot storage slot
     * @param _address address to be set
     */
    function _setAddressBySlot(bytes32 _slot, address _address) internal {
        assembly {
            sstore(_slot, _address)
        }
    }

    /**
     * @dev Internal helper function to get an address from a storage slot
     * @param _slot storage slot
     * @return _address from the storage slot
     */
    function _getAddressBySlot(bytes32 _slot) internal view returns (address _address) {
        assembly {
            _address := sload(_slot)
        }
    }

    /**
     * @dev Internal helper function to get a value from a storage slot
     * @param _slot storage slot
     * @return _value from the storage slot
     */
    function _getValueBySlot(bytes32 _slot) internal view returns (bytes32 _value) {
        assembly {
            _value := sload(_slot)
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2024
pragma solidity ^0.8.0;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IFirewall} from "../interfaces/IFirewall.sol";
import {IFirewallConsumer} from "../interfaces/IFirewallConsumer.sol";

/**
 * @title Firewall Consumer Base Contract
 * @author David Benchimol @ Ironblocks
 * @dev This contract is a parent contract that can be used to add firewall protection to any contract.
 *
 * The contract must define a firewall contract which will manage the policies that are applied to the contract.
 * It also must define a firewall admin which will be able to add and remove policies.
 *
 */
contract VennFirewallConsumerBase is IFirewallConsumer, Context {

    bytes4 private constant SUPPORTS_APPROVE_VIA_SIGNATURE_INTERFACE_ID = bytes4(0x0c908cff); // sighash of approveCallsViaSignature

    // This slot is used to store the firewall address
    bytes32 private constant FIREWALL_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall")) - 1);

    // This slot is used to store the firewall admin address
    bytes32 private constant FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall.admin")) - 1);

    // This slot is used to store the new firewall admin address (when changing admin)
    bytes32 private constant NEW_FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.new.firewall.admin")) - 1);

    bytes32 private constant ATTESTATION_CENTER_PROXY_SLOT = bytes32(uint256(keccak256("eip1967.attestation.center.proxy")) - 1);
    bytes32 private constant USER_PAID_FEE_SLOT = bytes32(uint256(keccak256("eip1967.user.paid.fee")) - 1);
    bytes32 private constant SAFE_FUNCTION_CALLER_SLOT = bytes32(uint256(keccak256("eip1967.safe.function.caller")) - 1);
    bytes32 private constant SAFE_FUNCTION_CALL_FLAG_SLOT = bytes32(uint256(keccak256("eip1967.safe.function.call.flag")) - 1);

    event FirewallAdminUpdated(address newAdmin);
    event FirewallUpdated(address newFirewall);

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall, applying each of
     * the subscribed policies.
     *
     * NOTE: Applying this modifier on functions that exit execution flow by an inline assmebly "return" call will
     * prevent the postExecution hook from running - breaking the protection provided by the firewall.
     * If you have any questions, please refer to the Firewall's documentation and/or contact our support.
     */
    modifier firewallProtected() {
        address firewall = _getAddressBySlot(FIREWALL_STORAGE_SLOT);
        if (firewall == address(0)) {
            _;
            return;
        }
        uint256 value = _msgValue();
        IFirewall(firewall).preExecution(_msgSender(), _msgData(), value);
        _;
        IFirewall(firewall).postExecution(_msgSender(), _msgData(), value);
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
        _setAddressBySlot(SAFE_FUNCTION_CALLER_SLOT, address(1));
        _setValueBySlot(SAFE_FUNCTION_CALL_FLAG_SLOT, 1);
    }

    function safeFunctionCall(
        uint256 userNativeFee,
        bytes calldata proxyPayload,
        bytes calldata data
    ) external payable {
        require(msg.value >= userNativeFee, "VennFirewallConsumer: Not enough ETH for fee");
        _initSafeFunctionCallFlags(userNativeFee);
        address attestationCenterProxy = _getAddressBySlot(ATTESTATION_CENTER_PROXY_SLOT);
        (bool success, ) = attestationCenterProxy.call{value: userNativeFee}(proxyPayload);
        require(success, "VennFirewallConsumer: Proxy call failed");
        // require(msg.sender == _msgSender(), "VennFirewallConsumer: No meta transactions");
        Address.functionDelegateCall(address(this), data);
        _deInitSafeFunctionCallFlags();
    }

    function _initSafeFunctionCallFlags(uint256 userNativeFee) internal {
        _setAddressBySlot(SAFE_FUNCTION_CALLER_SLOT, msg.sender);
        _setValueBySlot(SAFE_FUNCTION_CALL_FLAG_SLOT, 2);
        _setValueBySlot(USER_PAID_FEE_SLOT, userNativeFee);
    }

    function _deInitSafeFunctionCallFlags() internal {
        _setAddressBySlot(SAFE_FUNCTION_CALLER_SLOT, address(1));
        _setValueBySlot(SAFE_FUNCTION_CALL_FLAG_SLOT, 1);
        _setValueBySlot(USER_PAID_FEE_SLOT, 0);
    }

    function setAttestationCenterProxy(address attestationCenterProxy) external onlyFirewallAdmin {
        if (attestationCenterProxy != address(0)) {
            require(ERC165Checker.supportsERC165InterfaceUnchecked(attestationCenterProxy, SUPPORTS_APPROVE_VIA_SIGNATURE_INTERFACE_ID));
        }
        _setAddressBySlot(ATTESTATION_CENTER_PROXY_SLOT, attestationCenterProxy);
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
        emit FirewallUpdated(_firewall);
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
        emit FirewallAdminUpdated(msg.sender);
    }

    /**
     * @dev Internal helper funtion to get the msg.value
     * @return value of the msg.value
     */
    function _msgValue() internal view returns (uint256 value) {
        // We do this because msg.value can only be accessed in payable functions.
        assembly {
            value := callvalue()
        }
        if (uint256(_getValueBySlot(SAFE_FUNCTION_CALL_FLAG_SLOT)) == 2) {
            if (msg.sender == _getAddressBySlot(SAFE_FUNCTION_CALLER_SLOT)) {
                uint256 fee = uint256(_getValueBySlot(USER_PAID_FEE_SLOT));
                value = value - fee;
            }
        }
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

    function _setValueBySlot(bytes32 _slot, uint256 _value) internal {
        assembly {
            sstore(_slot, _value)
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

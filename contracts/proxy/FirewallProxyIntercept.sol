// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/IFirewall.sol";
import "../interfaces/IFirewallConsumer.sol";

/**
 * @title Firewall protected TransparentUpgradeableProxy
 * @author David Benchimol @ Ironblocks
 * @dev This contract acts the same as OpenZeppelins `TransparentUpgradeableProxy` contract,
 * but with Ironblocks firewall built in to the proxy layer.
 *
 * NOTE: This proxy is intended for specific use cases, and using it comes with some
 * behaviors that are by-design different from the standard TransparentUpgradeableProxy:
 *
 * 1) The Upgraded(address indexed implementation) event will be emitted when a FirewallAdmin makes
 * changes to the Firewall's settings (i.e. even though the implementation/logic contract was not changed).
 *
 * 2) Upgrading the implementation contract and initializing it are now separated into two separate calls.
 *
 * If any of these are a limitation for your use case, or you if you have any questions on how or when to use this
 * contract - please refer to the Firewall's documentation and/or contact our support.
 *
 */
contract FirewallProxyIntercept is TransparentUpgradeableProxy, IFirewallConsumer {

    bytes32 private constant FIREWALL_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall")) - 1);
    bytes32 private constant FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall.admin")) - 1);
    bytes32 private constant FIREWALL_INTERCEPT_IMPLEMENTATION_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall.intercept.implementation")) - 1);

    event FirewallAdminUpdated(address newAdmin);
    event FirewallUpdated(address newFirewall);
    event InterceptImplementationUpdated(address newInterceptImplementation);
    event StaticCallCheck();

    /**
     * @dev Initializes a firewall upgradeable proxy managed by `_admin`, backed by the implementation at `_logic`, and
     * optionally initialized with `_data` as explained in {ERC1967Proxy-constructor}.
     * Also sets _firewall and _firewallAdmin.
     */
    constructor(
        address _logic,
        address admin_
    )
        payable
        TransparentUpgradeableProxy(_logic, admin_, new bytes(0))
    {}

    function initialize(
        address _firewall,
        address _firewallAdmin,
        address _logic
    ) external ifAdmin {
        _changeFirewall(_firewall);
        _changeFirewallAdmin(_firewallAdmin);
        _changeFirewallInterceptImplementation(_logic);
    }

    /**
     * @dev If not firewall, fallback
     */
    modifier ifFirewallOrAdmin() {
        address _firewall = _getFirewall();
        address admin = _getAdmin();
        if (msg.sender == _firewall || msg.sender == admin) {
            _;
        } else {
            _fallback();
        }
    }

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall, applying each of
     * the subscribed policies.
     */
    modifier firewallProtected() {
        address _firewall = _getFirewall();
        // Skip if view function or firewall disabled
        if (_firewall == address(0) || _isStaticCall()) {
            _;
            return;
        }

        uint value;
        // We do this because msg.value can only be accessed in payable functions.
        assembly {
            value := callvalue()
        }
        IFirewall(_firewall).preExecution(msg.sender, msg.data, value);
        _;
        IFirewall(_firewall).postExecution(msg.sender, msg.data, value);
    }

    function staticCallCheck() external {
        emit StaticCallCheck();
    }

    function _isStaticCall() private returns (bool) {
        try this.staticCallCheck() {
            return false;
        } catch {
            return true;
        }
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove a policy from the consumers subscribed policies.
     */
    function changeFirewall(address _firewall) external ifAdmin {
        require(_firewall != address(0), "FirewallConsumer: zero address");
        _changeFirewall(_firewall);
    }

    /**
     * @dev Admin only function allowing the consumers admin to remove a policy from the consumers subscribed policies.
     */
    function changeFirewallAdmin(address _firewallAdmin) external ifAdmin {
        require(_firewallAdmin != address(0), "FirewallConsumer: zero address");
        _changeFirewallAdmin(_firewallAdmin);
    }

    /**
     * @dev Returns the current firewall address.
     *
     * NOTE: Only the admin can call this function. See {FirewallProxyAdmin-getProxyFirewall}.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0x5dd2e3b890564a8f99f7f203f226a27a8aa59aee19a4ece5cf5eaa77ab91f661`
     */
    function firewall() external ifAdmin returns (address) {
        return _getFirewall();
    }

    /**
     * @dev Returns the current firewall admin address.
     *
     * NOTE: Only the admin OR firewall can call this function. See {FirewallProxyAdmin-getProxyFirewallAdmin}.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0x29982a6ac507a2a707ced6dee5d76285dd49725db977de83d9702c628c974135`
     */
    function firewallAdmin() external ifFirewallOrAdmin returns (address) {
        return _getFirewallAdmin();
    }

    /**
     * @dev Returns the current firewall admin address.
     */
    function _getFirewallAdmin() private view returns (address) {
        return StorageSlot.getAddressSlot(FIREWALL_ADMIN_STORAGE_SLOT).value;
    }

    /**
     * @dev Stores a new address in the firewall admin slot.
     */
    function _changeFirewallAdmin(address _firewallAdmin) private {
        StorageSlot.getAddressSlot(FIREWALL_ADMIN_STORAGE_SLOT).value = _firewallAdmin;
        emit FirewallAdminUpdated(_firewallAdmin);
    }

    /**
     * @dev Stores a new address in the firewall intercept implementation slot.
     */
    function _changeFirewallInterceptImplementation(address _firewallInterceptImplementation) private {
        StorageSlot.getAddressSlot(FIREWALL_INTERCEPT_IMPLEMENTATION_STORAGE_SLOT).value = _firewallInterceptImplementation;
        emit InterceptImplementationUpdated(_firewallInterceptImplementation);
    }

    /**
     * @dev Returns the current firewall address.
     */
    function _getFirewall() private view returns (address) {
        return StorageSlot.getAddressSlot(FIREWALL_STORAGE_SLOT).value;
    }

    /**
     * @dev Stores a new address in the firewall implementation slot.
     */
    function _changeFirewall(address _firewall) private {
        StorageSlot.getAddressSlot(FIREWALL_STORAGE_SLOT).value = _firewall;
        emit FirewallUpdated(_firewall);
    }

    function _internalDelegate(address _toimplementation) private firewallProtected returns (bytes memory) {
        bytes memory ret_data = Address.functionDelegateCall(_toimplementation, msg.data);
        return ret_data;
    }

    /**
     * @dev We can't call `TransparentUpgradeableProxy._delegate` because it uses an inline `RETURN`
     *      Since we have checks after the implementation call we need to save the return data,
     *      perform the checks, and only then return the data
     */
    function _delegate(address) internal override {
        address interceptImplementation = StorageSlot.getAddressSlot(FIREWALL_INTERCEPT_IMPLEMENTATION_STORAGE_SLOT).value;
        bytes memory ret_data = _internalDelegate(interceptImplementation);
        uint256 ret_size = ret_data.length;

        // slither-disable-next-line assembly
        assembly {
            return(add(ret_data, 0x20), ret_size)
        }
    }
}

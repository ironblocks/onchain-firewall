// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/IFirewall.sol";
import "../interfaces/IFirewallConsumer.sol";

/**
 * @dev Interface for {FirewallProxyIntercept}. In order to implement transparency, {FirewallProxyIntercept}
 * does not implement this interface directly, and some of its functions are implemented by an internal dispatch
 * mechanism. The compiler is unaware that these functions are implemented by {FirewallProxyIntercept} and will not
 * include them in the ABI so this interface must be used to interact with it.
 */
interface IFirewallProxyIntercept {
    function firewallAdmin() external view returns (address);
    function changeFirewall(address) external;
    function changeFirewallAdmin(address) external;
}

/**
 * @title Firewall protected TransparentUpgradeableProxy
 * @author David Benchimol @ Ironblocks
 * @dev This contract acts the same as OpenZeppelins `TransparentUpgradeableProxy` contract,
 * but with Ironblocks firewall built in to the proxy layer.
 * 
 */
contract FirewallProxyIntercept is TransparentUpgradeableProxy {

    bytes32 private constant FIREWALL_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall")) - 1);
    bytes32 private constant FIREWALL_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall.admin")) - 1);
    bytes32 private constant FIREWALL_INTERCEPT_IMPLEMENTATION_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.firewall.intercept.implementation")) - 1);

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
     * @dev If caller is the admin process the call internally, otherwise if the caller is the firewall,
     * return the firewall admin, else transparently fallback to the proxy behavior
     */
    function _fallback() internal virtual override {
        if (msg.sender == _getAdmin()) {
            bytes memory ret;
            bytes4 selector = msg.sig;
            if (selector == IFirewallProxyIntercept.changeFirewall.selector) {
                ret = _dispatchChangeFirewall();
            } else if (selector == IFirewallProxyIntercept.changeFirewallAdmin.selector) {
                ret = _dispatchChangeFirewallAdmin();
            } else {
                super._fallback();
            }
            assembly {
                return(add(ret, 0x20), mload(ret))
            }
        } else if (msg.sender == _getFirewall()) {
            bytes memory ret;
            bytes4 selector = msg.sig;
            if (selector == IFirewallProxyIntercept.firewallAdmin.selector) {
                ret = _dispatchFirewallAdmin();
            } else {
                revert("TransparentUpgradeableProxy: firewall cannot fallback to proxy target");
            }
            assembly {
                return(add(ret, 0x20), mload(ret))
            } 
        } else {
            super._fallback();
        }
    }

    /**
     * @dev Admin only function allowing the consumers admin to change the firewall address
     */
    function _dispatchChangeFirewall() private returns (bytes memory) {
        _requireZeroMsgValue();
        address newFirewall = abi.decode(msg.data[4:], (address));
        require(newFirewall != address(0), "FirewallConsumer: zero address");
        _changeFirewall(newFirewall);
        return "";
    }

    /**
     * @dev Admin only function allowing the consumers admin to set a new admin
     */
    function _dispatchChangeFirewallAdmin() private returns (bytes memory) {
        _requireZeroMsgValue();
        address newFirewallAdmin = abi.decode(msg.data[4:], (address));
        require(newFirewallAdmin != address(0), "FirewallConsumer: zero address");
        _changeFirewallAdmin(newFirewallAdmin);
        return "";
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
    function _dispatchFirewallAdmin() private returns (bytes memory) {
        _requireZeroMsgValue();
        address firewallAdmin = _getFirewallAdmin();
        return abi.encode(firewallAdmin);
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
    }

    /**
     * @dev Stores a new address in the firewall intercept implementation slot.
     */
    function _changeFirewallInterceptImplementation(address _firewallInterceptImplementation) private {
        StorageSlot.getAddressSlot(FIREWALL_INTERCEPT_IMPLEMENTATION_STORAGE_SLOT).value = _firewallInterceptImplementation;
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

    /**
     * @dev To keep this contract fully transparent, all `ifAdmin` functions must be payable. This helper is here to
     * emulate some proxy functions being non-payable while still allowing value to pass through.
     */
    function _requireZeroMsgValue() private {
        require(msg.value == 0);
    }
}
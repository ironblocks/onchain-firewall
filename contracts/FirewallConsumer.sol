// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IFirewall.sol";
import "./interfaces/IFirewallConsumer.sol";

/**
 * @title Firewall Consumer
 * @author David Benchimol @ Ironblocks 
 * @dev This contract is a parent contract that can be used to add firewall protection to any contract.
 *
 * The contract must define a firewall contract which will manage the policies that are applied to the contract.
 * It also must define a firewall admin which will be able to add and remove policies.
 *
 */
contract FirewallConsumer is IFirewallConsumer {

    address private firewall;
    address public firewallAdmin;

    /**
     * @dev modifier that will run the preExecution and postExecution hooks of the firewall, applying each of
     * the subscribed policies.
     */
    modifier firewallProtected() {
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

}
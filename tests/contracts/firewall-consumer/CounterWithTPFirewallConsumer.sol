// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TransparentProxyFirewallConsumer} from "@ironblocks/firewall-consumer/contracts/proxies/TransparentProxyFirewallConsumer.sol";
import {UpgradeableCounterV1} from "../counter/UpgradeableCounterV1.sol";

import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

contract CounterWithTPFirewallConsumer is UpgradeableCounterV1, TransparentProxyFirewallConsumer {
    /**
     * ironblocks: _msgSender() & _msgData() & _contextSuffixLength() are inherited in ContextUpgradeable
     * and in FirewallConsumer, so we need to override them here to avoid the diamond inheritance problem.
     */
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, Context)
        returns (address)
    {
        return msg.sender;
    }

    function _msgData()
        internal
        pure
        override(ContextUpgradeable, Context)
        returns (bytes calldata)
    {
        return msg.data;
    }

    function _contextSuffixLength() internal pure override(ContextUpgradeable, Context) returns (uint256) {
        return 0;
    }
}
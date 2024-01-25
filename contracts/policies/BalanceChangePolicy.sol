// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FirewallPolicyBase.sol";

/**
 * @dev This policy asserts that a consumer contracts balance change (for eth or tokens) doesn't
 * exceed a configurable amount for a function call.
 */
contract BalanceChangePolicy is FirewallPolicyBase {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // consumer => token => uint
    mapping (address => mapping (address => uint)) public consumerMaxBalanceChange;
    // consumer => token => uint[]
    mapping (address => mapping(address => uint[])) public consumerLastBalance;

    mapping (address => address[]) private _consumerTokens;
    mapping (address => mapping(address => bool)) private _monitoringToken;

    constructor(address _firewallAddress) FirewallPolicyBase() {
        authorizedExecutors[_firewallAddress] = true;
    }

    function preExecution(address consumer, address, bytes memory, uint value) external isAuthorized(consumer) {
        address[] memory consumerTokens = _consumerTokens[consumer];
        for (uint i = 0; i < consumerTokens.length; i++) {
            address token = consumerTokens[i];
            uint preBalance = token == ETH ? address(consumer).balance - value : IERC20(token).balanceOf(consumer);
            consumerLastBalance[consumer][token].push(preBalance);
        }
    }

    function postExecution(address consumer, address, bytes memory, uint) external isAuthorized(consumer) {
        address[] memory consumerTokens = _consumerTokens[consumer];
        for (uint i = 0; i < consumerTokens.length; i++) {
            address token = consumerTokens[i];
            uint[] storage lastBalanceArray = consumerLastBalance[consumer][token];
            uint lastBalance = lastBalanceArray[lastBalanceArray.length - 1];
            uint postBalance = token == ETH ? address(consumer).balance : IERC20(token).balanceOf(consumer);
            uint difference = postBalance >= lastBalance ? postBalance - lastBalance : lastBalance - postBalance;
            require(difference <= consumerMaxBalanceChange[consumer][token], "BalanceChangePolicy: Balance change exceeds limit");
            lastBalanceArray.pop();
        }
    }

    function removeToken(
        address consumer,
        address token
    ) external onlyRole(POLICY_ADMIN_ROLE) {
        address[] storage consumerTokens = _consumerTokens[consumer];
        for (uint i = 0; i < consumerTokens.length; i++) {
            if (token == consumerTokens[i]) {
                consumerTokens[i] = consumerTokens[consumerTokens.length - 1];
                consumerTokens.pop();
                break;
            }
        }
        consumerMaxBalanceChange[consumer][token] = 0;
        _monitoringToken[consumer][token] = false;
    }

    function setConsumerMaxBalanceChange(
        address consumer,
        address token,
        uint maxBalanceChange
    ) external onlyRole(POLICY_ADMIN_ROLE) {
        consumerMaxBalanceChange[consumer][token] = maxBalanceChange;
        if (!_monitoringToken[consumer][token]) {
            _consumerTokens[consumer].push(token);
            _monitoringToken[consumer][token] = true;
        }
    }

    function getConsumerTokens(address consumer) external view returns (address[] memory) {
        return _consumerTokens[consumer];
    }
}

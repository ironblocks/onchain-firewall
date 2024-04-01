// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FirewallPolicyBase.sol";

/**
 * @dev This policy asserts that a consumer contracts balance change (for eth or tokens) doesn't
 * exceed a configurable amount for a function call.
 *
 * NOTE: This policy works by comparing the balance of the consumer before and after the function call.
 * Based on your use case and how your Firewall Consumer's functions are implemented, there may still
 * be a change to a user's balance which may exceed a configured threshold, if the change occurs
 * internally (i.e. in a scope not managed by this policy) but then returns below the threshold when
 * execution is given back to the policy.
 *
 * If you have any questions on how or when to use this modifier, please refer to the Firewall's documentation
 * and/or contact our support.
 */
contract BalanceChangePolicy is FirewallPolicyBase {
    // The address of the ETH token
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // consumer => token => uint
    mapping (address => mapping (address => uint)) public consumerMaxBalanceChange;

    // consumer => token => uint[]
    mapping (address => mapping(address => uint[])) public consumerLastBalance;

    // consumer => token[]
    mapping (address => address[]) private _consumerTokens;

    // consumer => token => bool
    mapping (address => mapping(address => bool)) private _monitoringToken;

    constructor(address _firewallAddress) FirewallPolicyBase() {
        authorizedExecutors[_firewallAddress] = true;
    }

    /**
     * @dev This function is called before the execution of a transaction.
     * It stores the current balance of the consumer before the transaction is executed.
     *
     * @param consumer The address of the contract that is being called.
     */
    function preExecution(address consumer, address, bytes memory, uint value) external isAuthorized(consumer) {
        address[] memory consumerTokens = _consumerTokens[consumer];
        for (uint i = 0; i < consumerTokens.length; i++) {
            address token = consumerTokens[i];
            uint preBalance = token == ETH ? address(consumer).balance - value : IERC20(token).balanceOf(consumer);
            consumerLastBalance[consumer][token].push(preBalance);
        }
    }

    /**
     * @dev This function is called after the execution of a transaction.
     * It checks that the balance change of the consumer doesn't exceed the configured amount.
     *
     * @param consumer The address of the contract that is being called.
     */
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

    /**
     * @dev This function is called to remove a token from the consumer's list of monitored tokens.
     *
     * @param consumer The address of the consumer contract.
     * @param token The address of the token to remove.
     */
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

    /**
     * @dev This function is called to set the maximum balance change for a consumer.
     *
     * @param consumer The address of the consumer contract.
     * @param token The address of the token to set the maximum balance change for.
     * @param maxBalanceChange The maximum balance change to set.
     */
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

    /**
     * @dev This function is called get the tokens that a consumer is monitoring.
     *
     * @param consumer The address of the consumer contract.
     */
    function getConsumerTokens(address consumer) external view returns (address[] memory) {
        return _consumerTokens[consumer];
    }
}

// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

interface IInvariantLogic {
    function assertInvariants(
        address consumer,
        bytes4 sighash,
        bytes32[] calldata preValues,
        bytes32[] calldata postValues
    ) external;
}
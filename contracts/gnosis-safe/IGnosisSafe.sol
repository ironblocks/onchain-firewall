// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IGuard.sol";

interface IGnosisSafe {
    function nonce() external view returns (uint);
    function encodeTransactionData(
        address to,
        uint256 value,
        bytes calldata data,
        IGuard.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes memory);
    function checkSignatures(bytes32 dataHash, bytes memory data, bytes memory signatures) external view;
}
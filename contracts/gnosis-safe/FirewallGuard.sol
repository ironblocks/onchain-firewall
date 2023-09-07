// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IGnosisSafe.sol";
import "../interfaces/IGuard.sol";
import "../interfaces/IFirewall.sol";

abstract contract BaseGuard is IGuard {
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return
            interfaceId == type(IGuard).interfaceId || // 0xe6d7a83a
            interfaceId == type(IERC165).interfaceId; // 0x01ffc9a7
    }
}

/**
 * @dev This contract is an implementation of gnosis safes "guard" interface.
 *
 * The guard is meant to allow custom logic to be executed before and after a safe transaction. This implementation
 * allows backwards compatibility with the existing firewall contract. The firewall contract is called before and after
 * the safe transaction and is responsible for making the decision on whether or not to allow the transaction to be executed.
 *
 */
contract FirewallGuard is IGuard, BaseGuard {

    mapping(bytes32 => uint) public bypassGuardInitTime;

    uint public constant MAX_BYPASS_GUARD_WAIT_TIME = 7 days;

    address public safe;
    address public firewall;
    address public firewallAdmin;
    uint public bypassGuardWaitTime;

    bytes private currentSafeData;
    address private currentMsgSender;
    uint private currentMsgValue;

    constructor(
        address _safe,
        address _firewall,
        address _firewallAdmin,
        uint _bypassGuardWaitTime
    ) {
        require(_safe != address(0), "FirewallGuard: safe cannot be zero address");
        require(_bypassGuardWaitTime <= MAX_BYPASS_GUARD_WAIT_TIME, "FirewallGuard: bypassGuardWaitTime too high");
        safe = _safe;
        firewall = _firewall;
        firewallAdmin = _firewallAdmin;
        bypassGuardWaitTime = _bypassGuardWaitTime;
    }

    function bypassGuard(
        address to,
        uint256 value,
        bytes memory data,
        Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external {
        uint nonce = IGnosisSafe(safe).nonce();
        bytes memory txHashData = IGnosisSafe(safe).encodeTransactionData(
            // Transaction info
            to,
            value,
            data,
            operation,
            safeTxGas,
            // Payment info
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            // Signature info
            nonce
        );
        bytes32 txHash = keccak256(txHashData);
        require(bypassGuardInitTime[txHash] == 0, "FirewallGuard: bypassGuard already called");
        IGnosisSafe(safe).checkSignatures(txHash, txHashData, signatures);
        bypassGuardInitTime[txHash] = block.timestamp;
    }

    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures,
        address msgSender
    ) external {
        require(msg.sender == safe, "FirewallGuard: only safe can call");

        bytes32 txHash;
        {
            uint nonce = IGnosisSafe(safe).nonce();
            bytes memory txHashData = IGnosisSafe(safe).encodeTransactionData(
                // Transaction info
                to,
                value,
                data,
                operation,
                safeTxGas,
                // Payment info
                baseGas,
                gasPrice,
                gasToken,
                refundReceiver,
                // Signature info
                nonce - 1 // We subtract 1 because the nonce is incremented before the transaction is executed
            );
            txHash = keccak256(txHashData);
        }

        // If bypassGuard was called, allow the transaction to be executed if the wait time has passed
        // without checking firewall.
        if (
            bypassGuardInitTime[txHash] > 0 &&
            block.timestamp > bypassGuardInitTime[txHash] + bypassGuardWaitTime
        ) return;

        bytes memory safeData = abi.encodeWithSelector(
            0x6a761202,
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            signatures
        );
        currentSafeData = safeData;
        currentMsgSender = msgSender;
        currentMsgValue = value;
        IFirewall(firewall).preExecution(msgSender, safeData, value);
    }

    function checkAfterExecution(bytes32 txHash, bool) external {
        require(msg.sender == safe, "FirewallGuard: only safe can call");
        if (
            bypassGuardInitTime[txHash] > 0 &&
            block.timestamp > bypassGuardInitTime[txHash] + bypassGuardWaitTime
        ) {
            bypassGuardInitTime[txHash] = 0;
            return;
        }
        IFirewall(firewall).postExecution(currentMsgSender, currentSafeData, currentMsgValue);
    }
}
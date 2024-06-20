// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

contract UpgradeableCounterV2 is Initializable, OwnableUpgradeable {
    bytes32 private constant COUNT_SLOT = keccak256("count.slot");

    function initialize() external initializer {
        __Ownable_init(msg.sender);
        StorageSlot.getUint256Slot(COUNT_SLOT).value = 0;
    }

    function increment2() public {
        StorageSlot.getUint256Slot(COUNT_SLOT).value += 2;
    }

    function decrement2() public {
        StorageSlot.getUint256Slot(COUNT_SLOT).value -= 2;
    }

    function getCount() public view returns (uint256) {
        return StorageSlot.getUint256Slot(COUNT_SLOT).value;
    }
}
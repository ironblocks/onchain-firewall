// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../samples/SampleConsumer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract SampleContractUser {

    function depositAndWithdraw(address sampleConsumer) external payable {
        SampleConsumer(sampleConsumer).deposit{value: msg.value}();
        SampleConsumer(sampleConsumer).withdraw(msg.value);
    }

    receive() external payable {}
}


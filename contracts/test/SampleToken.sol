// SPDX-License-Identifier: UNLICENSED
// See LICENSE file for full license text.
// Copyright (c) Ironblocks 2023
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SampleToken is ERC20 {

    constructor() ERC20("TEST", "TEST") {
        _mint(msg.sender, 1000e18);
    }
}


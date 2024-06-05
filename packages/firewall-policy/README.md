# <img src="https://www.ironblocks.com/logo.svg" alt="Ironblocks" height="40px">


### Usage

Once installed, you can use the contracts in the library by importing them:

```solidity
pragma solidity 0.8.19;

import "./FirewallPolicyBase.sol";

/**
 * @dev A custom policy that enforces my business rules
 */
contract MyPolicy is FirewallPolicyBase {

    function preExecution(address consumer, address sender, bytes calldata data, uint value) external override {
        // my logic here
    }

    function postExecution(address consumer, address sender, bytes calldata data, uint value) external override {
        // my logic here
    }

}
```

To keep your system secure, you should **always** use the installed code as-is, and neither copy-paste it from online sources nor modify it yourself. The library is designed so that only the contracts and functions you use are deployed, so you don't need to worry about it needlessly increasing gas costs.

## Security

This project is maintained by [Ironblocks](https://www.ironblocks.com/) with the goal of providing a secure and reliable library of smart contract components for the ecosystem. We address security through risk management in various areas such as engineering and open source best practices, scoping and API design, multi-layered review processes, and incident response preparedness.

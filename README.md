# OnChain Firewall Monorepo

![Ironblocks](packages//onchain-firewall/ironblocks-logo.svg)

Welcome to the OnChain Firewall monorepo. This repository contains multiple packages that work together to provide a robust onchain firewall solution for protecting smart contracts. Below is an overview of the various packages included in this repository.

## Packages

### [onchain-firewall](packages/onchain-firewall)

This is the main OnChain Firewall project. It provides the core functionality and features for the firewall.

-   **Status**: Active
-   **Description**: The core logic and components for setting up and maintaining an onchain firewall to protect your smart contracts.
-   **Directory**: `packages/onchain-firewall`

### [firewall-consumer](packages/firewall-consumer)

Smart contracts that builders use to protect their projects using the OnChain Firewall.

-   **Status**: Active
-   **Description**: Prebuilt smart contracts that can be deployed and integrated into various projects to enhance their security using the OnChain Firewall.
-   **Directory**: `packages/firewall-consumer`

### [firewall-policy](packages/firewall-policy)

An SDK to build your own custom policies for the OnChain Firewall.

-   **Status**: Active
-   **Description**: A development kit that allows builders to create custom security policies tailored to their specific needs.
-   **Directory**: `packages/firewall-policy`

## Getting Started

### Root Dependencies

Most of the dependencies in this monorepo can be hoisted by NPM. Install them by running:

```shell
npm install
```

### Package Dependencies

In addition, make sure to also install un-hoisted dependencies in each package, by running:

```shell
cd packages/<package-folder>
npm install
```

Next, please refer to the `README.md` files of packages you'll be working with for any additional details.

## License

This monorepo is licensed under the terms specified in the LICENSE file of each individual.

## Contributing

We welcome contributions! Please check the individual package directories for specific contributing guidelines.

## Support

For any help or questions, please open an issue on this repository, or contact us at `firewall@ironblocks.com`.

## About Ironblocks

Ironblocks is dedicated to providing advanced security solutions for blockchain applications. Our OnChain Firewall is designed to safeguard your smart contracts with state-of-the-art security policies and tools.

Visit us at [www.ironblocks.com](https://www.ironblocks.com)

Learn more at [Ironblocks Documentation](https://docs.ironblocks.com)
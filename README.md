# <h1 align="center"> Hardhat x Foundry Template </h1>

This is the Maian Ecosystem Monorepo. This branch includes the following components to be audited:
 - [Ulysses Omnichain Token Management and Cross Chain Communication](./src/ulysses-omnichain/)

## Ulysses
To learn more about Ulysses, please visit the [Ulysses Documentation](https://v2-docs.maiadao.io/protocols/Ulysses/introduction).

## solidity-rlp-encode
This repository uses `RLPEncode` that is an [RLP encoding](https://github.com/ethereum/wiki/wiki/RLP) library written in Solidity. The original author of this library is [Bakaoh](https://github.com/bakaoh). This repository cleans up the original code and adds tests for the standard RLP encoding test cases.

**Template repository for getting started quickly with Hardhat and Foundry in one project**

![Github Actions](https://github.com/devanonon/hardhat-foundry-template/workflows/test/badge.svg)

### Getting Started

 * Use Foundry: 
```bash
forge install
forge test
```

 * To pass all tests, it is necessary to run:
```bash
forge test --gas-price [gas_price]
```


 * Use Hardhat:
```bash
npm install
```

### Features

 * Write / run tests with either Hardhat or Foundry:
```bash
forge test
# or
npx hardhat test
```

 * Use Hardhat's task framework
```bash
npx hardhat example
```

 * Install libraries with Foundry which work with Hardhat.
```bash
forge install rari-capital/solmate # Already in this repo, just an example
```

### Notes

Whenever you install new libraries using Foundry, make sure to update your `remappings.txt` file by running `forge remappings > remappings.txt`. This is required because we use `hardhat-preprocessor` and the `remappings.txt` file to allow Hardhat to resolve libraries you install with Foundry.

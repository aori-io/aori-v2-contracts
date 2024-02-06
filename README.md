# Aori V2 Smart Contract

A template for quickly getting started with forge

## Getting Started

```
git clone https://github.com/aori-io/aori-v2-contracts
git submodule update --init --recursive  ## initialize submodule dependencies
forge build
make tests ## run tests
```

## Deployments

| Chain | Address Deployed To|
| --- | --- |
| `5 (Goerli)` | [0x6A979916234013AbA003d906e4e7136496B90AA6](https://goerli.etherscan.io/address/0x6A979916234013AbA003d906e4e7136496B90AA6#code) | 
| `11155111 (Sepolia)` | [0x6A979916234013AbA003d906e4e7136496B90AA6](https://sepolia.etherscan.io/address/0x6A979916234013AbA003d906e4e7136496B90AA6#code) |
| `421614 (Arbitrum Sepolia)` | [0x6A979916234013AbA003d906e4e7136496B90AA6](https://sepolia.arbiscan.io/address/0x6A979916234013AbA003d906e4e7136496B90AA6#code) |

### Verification

```
forge verify-contract 0x6A979916234013AbA003d906e4e7136496B90AA6 src/AoriV2.sol:AoriV2 --optimizer-runs 1000000 --show-standard-json-input > single-chain-aori-v2-etherscan.json
```

### CI with Github Actions

Automatically run linting and tests on pull requests.
## Acknowledgement

Inspired by great dapptools templates like https://github.com/gakonst/forge-template, https://github.com/gakonst/dapptools-template and https://github.com/transmissions11/dapptools-template

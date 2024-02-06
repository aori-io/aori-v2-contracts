# Aori V2 Smart Contracts

![.](assets/aori.svg)

Aori is a high-performance orderbook protocol for high-frequency trading on-chain and facilitating OTC settlement.

This repo is released under the [MIT License](LICENSE).

You can read more about the protocol in our litepaper [here](https://aori-io.notion.site/Aori-A-Litepaper-62f809b5c25c4798ad2c1d48d883e7bd?pvs=4).


If you have any further questions, refer to [the technical documentation](https://www.aori.io/developers). Alternatively, please reach out to us [on Discord](https://discord.gg/K37wkh2ZfR) or [on Twitter](https://twitter.com/aori_io).

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

### Dependencies

```
forge install
```

### Compilation

```
forge build
```

### Testing

```
forge test --fork-url https://rpc.ankr.com/eth --via-ir
```

You can also test using the `make` command which will run the above command.

### Verification

```
forge verify-contract 0x6A979916234013AbA003d906e4e7136496B90AA6 src/AoriV2.sol:AoriV2 --optimizer-runs 1000000 --show-standard-json-input > single-chain-aori-v2-etherscan.json
```
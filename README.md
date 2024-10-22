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

### Mainnets

| Chain              |                                                       `Aori v2.3.1`                                                        |
| ------------------ | :------------------------------------------------------------------------------------------------------------------------: |
| `42161 (Arbitrum)` | [0xD5E8C18c5220B4d07d496fac5Fd973a3cE99b506](https://arbiscan.io/address/0xD5E8C18c5220B4d07d496fac5Fd973a3cE99b506#code)  |
| `8453 (Base)`      | [0xD5E8C18c5220B4d07d496fac5Fd973a3cE99b506](https://basescan.org/address/0xD5E8C18c5220B4d07d496fac5Fd973a3cE99b506#code) |

### Testnets

| Chain                |                                                           `Aori v2.3.1`                                                            |
| -------------------- | :--------------------------------------------------------------------------------------------------------------------------------: |
| `11155111 (Sepolia)` | [0xD5E8C18c5220B4d07d496fac5Fd973a3cE99b506](https://sepolia.etherscan.io/address/0xD5E8C18c5220B4d07d496fac5Fd973a3cE99b506#code) |

### Dependencies

```
forge install
```

### Compilation

```
make build
```

### Testing

```
forge test --fork-url https://rpc.ankr.com/eth --via-ir
```

You can also test using the `make tests` command which will run the above command.

### Verification

```
make generate-etherscan
```

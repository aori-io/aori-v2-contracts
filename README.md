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

| Chain | `Aori v2.2` | `Aori v2.1` | `Aori v2.0` |
| --- | :---: | :---: | :---: |
| `1 (Ethereum)` | [0x0AD86842EadEe5b484E31db60716EB6867B46e21](https://etherscan.io/address/0x0AD86842EadEe5b484E31db60716EB6867B46e21#code) | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://etherscan.io/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [0x6A979916234013AbA003d906e4e7136496B90AA6](https://etherscan.io/address/0x6A979916234013AbA003d906e4e7136496B90AA6#code) |
| `10 (Optimism) ` | [0x0AD86842EadEe5b484E31db60716EB6867B46e21](https://optimistic.etherscan.io/address/0x0AD86842EadEe5b484E31db60716EB6867B46e21#code) | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://optimistic.etherscan.io/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [0x6A979916234013AbA003d906e4e7136496B90AA6](https://optimistic.etherscan.io/address/0x6A979916234013AbA003d906e4e7136496B90AA6#code) |
| `56 (BNB Smart Chain) ` | [-]() | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://bscscan.com/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [-](-) |
| `100 (Gnosis Chain) ` | [-]() | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://gnosisscan.io/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [-](-) |
| `137 (Polygon) ` | [0x0AD86842EadEe5b484E31db60716EB6867B46e21](https://polygonscan.com/address/0x0AD86842EadEe5b484E31db60716EB6867B46e21#code) | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://polygonscan.com/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [-](-) |
| `8453 (Base)` | [0x0AD86842EadEe5b484E31db60716EB6867B46e21](https://basescan.org/address/0x0AD86842EadEe5b484E31db60716EB6867B46e21#code) | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://basescan.org/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [-]() |
| `42161 (Arbitrum One)` | [0x0AD86842EadEe5b484E31db60716EB6867B46e21](https://arbiscan.io/address/0x0AD86842EadEe5b484E31db60716EB6867B46e21#code) | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://arbiscan.io/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [0x6A979916234013AbA003d906e4e7136496B90AA6](https://arbiscan.io/address/0x6A979916234013AbA003d906e4e7136496B90AA6#code) |
| `42220 (Celo)` | [-]() | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://celoscan.io/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [-](-) |
| `43114 (Avalanche)` | [0x0AD86842EadEe5b484E31db60716EB6867B46e21](https://snowtrace.io/address/0x0AD86842EadEe5b484E31db60716EB6867B46e21#code) | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://snowtrace.io/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [-](-) |
| `59144 (Linea)` | [-]() | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://lineascan.build/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [-](-) |
| `81457 (Blast Mainnet)` | [0x0AD86842EadEe5b484E31db60716EB6867B46e21](https://blastscan.io/address/0x0AD86842EadEe5b484E31db60716EB6867B46e21#code) | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://blastscan.io/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [-](-) |
| `534352 (Scroll)` | [-]() | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://scrollscan.com/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [-](-) |

### Testnets

| Chain | `Aori v2.2` | `Aori v2.1` | `Aori v2.0` |
| --- | :---: | :---: | :---: |
| `336 (MEVM M1)` | [-]() | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5]() | [-]() |
| `80085 (Berachain Artio) ` | [0x0AD86842EadEe5b484E31db60716EB6867B46e21](https://artio.beratrail.io/address/0x0AD86842EadEe5b484E31db60716EB6867B46e21#code) | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://artio.beratrail.io/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5) | [-](-) |
| `421614 (Arbitrum Sepolia)` | [0x0AD86842EadEe5b484E31db60716EB6867B46e21](https://sepolia.arbiscan.io/address/0x0AD86842EadEe5b484E31db60716EB6867B46e21#code) | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://sepolia.arbiscan.io/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [0x6A979916234013AbA003d906e4e7136496B90AA6](https://sepolia.arbiscan.io/address/0x6A979916234013AbA003d906e4e7136496B90AA6#code) |
| `11155111 (Sepolia)` | [0x0AD86842EadEe5b484E31db60716EB6867B46e21](https://sepolia.etherscan.io/address/0x0AD86842EadEe5b484E31db60716EB6867B46e21#code) | [0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5](https://sepolia.etherscan.io/address/0xcc1A0DA89593441571f35Dd99a0aC1856d3F1FB5#code) | [0x6A979916234013AbA003d906e4e7136496B90AA6](https://sepolia.etherscan.io/address/0x6A979916234013AbA003d906e4e7136496B90AA6#code) |

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
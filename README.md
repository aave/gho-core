[![Build pass](https://github.com/aave/gho/actions/workflows/node.js.yml/badge.svg)](https://github.com/aave/gho/actions/workflows/node.js.yml)

```
        .///.                .///.     //.            .//  `/////////////-
       `++:++`              .++:++`    :++`          `++:  `++:......---.`
      `/+: -+/`            `++- :+/`    /+/         `/+/   `++.
      /+/   :+/            /+:   /+/    `/+/        /+/`   `++.
  -::/++::`  /+:       -::/++::` `/+:    `++:      :++`    `++/:::::::::.
  -:+++::-`  `/+:      --++/---`  `++-    .++-    -++.     `++/:::::::::.
   -++.       .++-      -++`       .++.    .++.  .++-      `++.
  .++-         -++.    .++.         -++.    -++``++-       `++.
 `++:           :++`  .++-           :++`    :+//+:        `++:----------`
 -/:             :/-  -/:             :/.     ://:         `/////////////-
```

# Gho

This repository contains the source code, tests and deployments for both GHO itself and the first facilitator integrating Aave. The repository uses [Hardhat](https://hardhat.org/) development framework.

## Description

GHO is a decentralized protocol-agnostic stablecoin which supports integrations with mutliple minters, known as facilitators. The first facilitator will be the Aave V3 Ethereum Mainnet market, where GHO will be borrowable akin to all other assets, but with an interest rate set by Aave governance.

Furthermore, Aave governance has the ability to set and remove other facilitators and manage their bucket capacities, or their total amount mintable.

## Documentation

See the link to the technical paper

- [Technical Paper](./techpaper/GHO_Technical_Paper.pdf)

## Getting Started

Clone the repository and in order to install dependencies, run:

```sh
npm i
```

If you need to interact with GHO in the Goerli testnet, provide your Alchemy api key and mnemonic in the `.env` file:

```sh
cp .env.example .env
# Fill ALCHEMY_KEY and MNEMONIC in the .env file with your editor
code .env
```

Compile contracts:

```sh
npm run compile
```

Run the test suite:

```sh
npm run test
```

Deploy and setup GHO in local Hardhat network:

```sh
npm run deploy-testnet
```

Deploy and setup GHO in Goerli testnet:

```sh
npm run deploy-testnet:goerli
```

## Connect with the community

You can join the [Discord](http://aave.com/discord) channel or the [Governance Forum](https://governance.aave.com/) to ask questions about the protocol or talk about Gho with other peers.

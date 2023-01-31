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

GHO is a decentralized, protocol-agnostic crypto-asset intended to maintain a stable value. GHO is minted and burned by approved entities named Facilitators. 

The first facilitator is the Aave V3 Ethereum Pool, which allows users to mint GHO against their collateral assets, based on the interest rate set by the Aave Governance. In addition, there is a FlashMint module as second facilitator, which facilitates arbitrage and liquidations, providing instant liquidity.

Furthermore, the Aave Governance has the ability to approve entities as Facilitators and manage the total amount of GHO they can generate (also known as bucket's capacity).

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

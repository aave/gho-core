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

The first facilitator is the Aave V3 Ethereum Pool, which allows users to mint GHO against their collateral assets, based on the interest rate set by the Aave Governance. In addition, there is a FlashMint module as a second facilitator, which facilitates arbitrage and liquidations, providing instant liquidity.

Furthermore, the Aave Governance has the ability to approve entities as Facilitators and manage the total amount of GHO they can generate (also known as bucket's capacity).

## Documentation

See the link to the technical paper

- [Technical Paper](./techpaper/GHO_Technical_Paper.pdf)
- [Developer Documentation](https://docs.gho.xyz/)

## Audits and Formal Verification

You can find all audit reports under the [audits](./audits/) folder

- [12-08-2022 - OpenZeppelin](./audits/12-08-2022_Openzeppelin-v1.pdf)
- [10-11-2022 - OpenZeppelin](./audits/10-11-2022_Openzeppelin-v2.pdf)
- [07-03-2023 - Sigma Prime](./audits/07-03-2023_SigmaPrime.pdf)
- [02-06-2023 - Sigma Prime](./audits/02-06-2023_SigmaPrime.pdf)
- [01-03-2023 - ABDK](./audits/01-03-2023_ABDK.pdf)
- [02-28-2023 - Certora Formal Verification](./certora/reports/Aave_Gho_Formal_Verification_Report.pdf)

## Getting Started

Clone the repository and run the following command to install dependencies:

```sh
npm i
```

If you need to interact with GHO in the Goerli testnet, provide your Alchemy API key and mnemonic in the `.env` file:

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

Deploy and setup GHO in a local Hardhat network:

```sh
npm run deploy-testnet
```

Deploy and setup GHO in Goerli testnet:

```sh
npm run deploy-testnet:goerli
```

## Connect with the community

You can join the [Discord](http://aave.com/discord) channel or the [Governance Forum](https://governance.aave.com/) to ask questions about the protocol or talk about Gho with other peers.

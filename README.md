# ⚠️ This repository is DEPRECATED and no longer maintained ⚠️

For the latest GHO code visit the GHO Origin Repository [here](https://github.com/aave-dao/gho-origin).

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

- [2022-08-12 - OpenZeppelin](./audits/2022-08-12_Openzeppelin-v1.pdf)
- [2022-11-10 - OpenZeppelin](./audits/2022-11-10_Openzeppelin-v2.pdf)
- [2023-03-01 - ABDK](./audits/2023-03-01_ABDK.pdf)
- [2023-02-28 - Certora Formal Verification](./certora/reports/Aave_Gho_Formal_Verification_Report.pdf)
- [2023-07-06 - Sigma Prime](./audits/2023-07-06_SigmaPrime.pdf)
- [2023-06-13 - Sigma Prime (GhoSteward)](./audits/2023-06-13_GhoSteward_SigmaPrime.pdf)
- [2023-09-20 - Emanuele Ricci @Stermi (GHO Stability Module)](./audits/2023-09-20_GSM_Stermi.pdf)
- [2023-10-23 - Sigma Prime (GHO Stability Module)](./audits/2023-10-23_GSM_SigmaPrime.pdf)
- [2023-12-07 - Certora Formal Verification (GHO Stability Module)](./certora/reports/Formal_Verification_Report_of_GHO_Stability_Module.pdf)
- [2024-03-14 - Certora Formal Verification (GhoStewardV2)](./audits/2024-03-14_GhoStewardV2_Certora.pdf)
- [2024-06-11 - Certora Formal Verification (UpgradeableGHO)](./audits/2024-06-11_UpgradeableGHO_Certora.pdf)
- [2024-06-11 - Certora Formal Verification (Modular Gho Stewards)](./audits/2024-09-15_ModularGhoStewards_Certora.pdf)

## Getting Started

Clone the repository and run the following command to install dependencies:

```sh
npm i
forge i
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

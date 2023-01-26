# Gho

## Description

Gho is a collateral backed stablecoin that can be natively integrated into the Aave Protocol

## Repo Outline

This project uses hardhat for compilation and deployment.

Hardhat provides two pieces of functionality not available yet in Foundry:

- coverage reports
- working with multiple versions of solidity

## Getting Started

`git clone git@github.com:aave/gho.git`

`cp .env.example .env` and add your `$ALCHEMY_KEY`

Install the dependencies

```sh
npm i
```

Compile the contracts

```sh
npm run compile
```

Run the test suite

```sh
npm run test-all
```

## Formatting

This repo is setup to format solidty files with prettier per the included `.prettierrc` file. It is recommended to configure this with your text editor so that formatting updates are made automatically. Another option is to handle this manually, by running:

```
npx prettier --check "src/**/*.sol" --config ./.prettierrc
npx prettier --write "src/**/*.sol" --config ./.prettierrc
```

or

```
make write_prettier
make check_prettier
```

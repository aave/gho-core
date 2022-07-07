# Gho

# Description

Gho is a collateral backed stablecoin that can be natively integrated into the Aave Mark

# Repo Outline

This project uses a combination of hardhat and foundry.

Hardhat provides two pieces of functionality not available yet in Foundry:

- coverage reports
- working with multiple versions of solidity

Foundry is included because while it doesn't have these core features it allows for:

- super rapid testing
- easy unit testing
- easy fuzzing and invariant testing

Hardhat and Foundry will work independently per the commands available in the makefile outlined in more detail below.

To create an environment where both hardhat and foundry can be used the following steps are taken:

1. Run a local hardhat node that forks mainnet
2. Use Hardhat Tasks to deploy necessary Gho contracts
3. Use Hardhat or Forge to interact with and test the deployed contracts on the local network
4. Reset and redeploy contracts on the local node as necessary

# Getting Started

Clone https://github.com/aave/gho

We use foundry for development which you will need to install locally from https://github.com/gakonst/foundry

Add a `.env` file with an `$ALCHEMY_KEY`

run `npm install`
run `make hardhat_test` and confirm the tests run successfully

run `forge install` to install the project dependencies
run `make forge_test` and confirm the tests run successfully

# Commands

Hardhat:
`make hardhat_compile`

`make hardhat_test`

Forge:
`make forge_build`

`make forge_test`

Combo:
Window 1:

`make start_network`
Window 2:

`make hardhat_local_test`
`make forge_local_test`

# Formatting

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

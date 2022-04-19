# Antei

# Getting Started

Clone https://github.com/aave/antei-poc-v3

We use foundry for development which you will need to install locally from https://github.com/gakonst/foundry

run `forge install` to install the project dependencies

then add a `.env` file with an `$ALCHEMY_KEY`

# Commands

To compile the solidity file: `forge build` or `make build`

To run the basic tests you can use: `forge test` or `make test`

To run the fork tests you can use: `make fork_test`. If you need logging the following commands are also available and the equivalent of running `forge test -v...`:

```
make test_v
make test_vv
make test_vvv
make test_vvvv

make fork_test_v
make fork_test_vv
make fork_test_vvv
make fork_test_vvvv
```

# Formatting

This repo is setup to format solidty files with prettier per the included `.prettierrc` file. It is recommended to configure this with your text editor so that formatting updates are made automatically. Another option is to handle this manually, by running:

```
npx prettier --check "src/**/*.sol" --config ./.prettierrc
```
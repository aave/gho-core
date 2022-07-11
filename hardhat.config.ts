import { config } from 'dotenv';
import { HardhatUserConfig } from 'hardhat/types';
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from 'hardhat/builtin-tasks/task-names';
import { subtask } from 'hardhat/config';

import '@typechain/hardhat';
import '@typechain/ethers-v5';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import 'hardhat-deploy';
import 'solidity-coverage';
import 'hardhat-contract-sizer';

config();

import { accounts } from './src/helpers/test-wallets';

// Prevent to load tasks before compilation and typechain
if (!process.env.SKIP_LOAD) {
  require('./src/tasks/set-DRE');
  require('./src/tasks/setup/gho-setup');
  require('./src/tasks/setup/initialize-gho-reserve');
  require('./src/tasks/setup/set-gho-oracle');
  require('./src/tasks/setup/enable-gho-borrowing');
  require('./src/tasks/setup/add-gho-as-entity');
  require('./src/tasks/setup/set-gho-addresses');
  require('./src/tasks/setup/upgrade-pool');
  require('./src/tasks/setup/upgrade-stkAave');
}

// Ignore Foundry tests
subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS).setAction(async (_, __, runSuper) => {
  const paths = await runSuper();
  return paths.filter((p) => !p.endsWith('.t.sol'));
});

const hardhatConfig: HardhatUserConfig = {
  networks: {
    hardhat: {
      accounts: accounts.map(({ secretKey, balance }: { secretKey: string; balance: string }) => ({
        privateKey: secretKey,
        balance,
      })),
      throwOnTransactionFailures: true,
      throwOnCallFailures: true,
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 14781440,
      },
    },
    localhost: {
      url: 'http://127.0.0.1:8545',
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 14781440,
      },
    },
  },
  solidity: {
    compilers: [
      {
        // Docs for the compiler https://docs.soliditylang.org/en/v0.8.10/using-the-compiler.html
        version: '0.8.10',
        settings: {
          optimizer: {
            enabled: true,
            runs: 100000,
          },
          evmVersion: 'london',
        },
      },
      {
        version: '0.8.0',
      },
      {
        version: '0.7.0',
        settings: {},
      },
      {
        version: '0.7.5',
        settings: {
          optimizer: { enabled: true, runs: 200 },
          evmVersion: 'istanbul',
        },
      },
      {
        version: '0.6.12',
        settings: {
          optimizer: { enabled: true, runs: 200 },
          evmVersion: 'istanbul',
        },
      },
    ],
  },
  paths: {
    sources: './src/contracts',
    tests: './src/test/',
    cache: './cache',
    artifacts: './artifacts',
  },
  namedAccounts: {
    deployer: 0,
  },
  typechain: {
    outDir: 'types',
    target: 'ethers-v5',
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    externalArtifacts: [], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
  },
};

export default hardhatConfig;

import { getCommonNetworkConfig, hardhatNetworkSettings } from './src/helpers/hardhat-config';
import { config } from 'dotenv';
import { HardhatUserConfig } from 'hardhat/types';
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from 'hardhat/builtin-tasks/task-names';
import { subtask } from 'hardhat/config';
import { DEFAULT_NAMED_ACCOUNTS, eEthereumNetwork } from '@aave/deploy-v3';
import '@nomicfoundation/hardhat-toolbox';
import 'hardhat-deploy';
import 'hardhat-contract-sizer';
import 'hardhat-dependency-compiler';
import 'hardhat-tracer';

config();

import { loadHardhatTasks } from './src/helpers/misc-utils';
import '@aave/deploy-v3';

// Prevent to load tasks before compilation and typechain
if (!process.env.SKIP_LOAD) {
  loadHardhatTasks(['misc', 'testnet-setup', 'roles', 'main']);
}

const hardhatConfig: HardhatUserConfig = {
  networks: {
    hardhat: hardhatNetworkSettings,
    goerli: getCommonNetworkConfig(eEthereumNetwork.goerli, 5),
    sepolia: getCommonNetworkConfig('sepolia', 11155111),
    localhost: {
      url: 'http://127.0.0.1:8545',
      ...hardhatNetworkSettings,
    },
  },
  solidity: {
    compilers: [
      {
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
    ...DEFAULT_NAMED_ACCOUNTS,
  },
  typechain: {
    outDir: 'types',
    target: 'ethers-v5',
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS ? true : false,
  },
  mocha: {
    timeout: 0,
    bail: true,
  },
  external: {
    contracts: [
      {
        artifacts: './artifacts',
        deploy: 'node_modules/@aave/deploy-v3/dist/deploy',
      },
    ],
  },
  tracer: {
    nameTags: {},
  },
};

export default hardhatConfig;

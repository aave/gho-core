import { getCommonNetworkConfig, hardhatNetworkSettings } from './helpers/hardhat-config';
import { config } from 'dotenv';
import { HardhatUserConfig } from 'hardhat/types';
import { DEFAULT_NAMED_ACCOUNTS, eEthereumNetwork, eAvalancheNetwork } from '@aave/deploy-v3';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-foundry';
import 'hardhat-deploy';
import 'hardhat-contract-sizer';
import 'hardhat-tracer';

config();

import { loadHardhatTasks } from './helpers/misc-utils';
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
    baseSepolia: getCommonNetworkConfig('baseSepolia', 84532),
    fuji: getCommonNetworkConfig(eAvalancheNetwork.fuji, 43113),

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
    sources: './src/',
    tests: './test/',
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
        artifacts: 'node_modules/@aave/deploy-v3/artifacts',
        deploy: 'node_modules/@aave/deploy-v3/dist/deploy',
      },
    ],
  },
  tracer: {
    nameTags: {},
  },
  etherscan: {
    apiKey: {
      baseSepolia: process.env.ETHERSCAN_API_KEY || '',
      fuji: 'snowtrace', // NOT REQUIRED
    },
    customChains: [
      {
        network: 'baseSepolia',
        chainId: 84532,
        urls: {
          apiURL: 'https://api-sepolia.basescan.org/api',
          browserURL: 'https://sepolia.basescan.org/',
        },
      },

      {
        network: 'fuji',
        chainId: 43113,
        urls: {
          apiURL: 'https://api.routescan.io/v2/network/testnet/evm/43113/etherscan',
          browserURL: 'https://testnet.snowtrace.io',
        },
      },
    ],
  },
};

export default hardhatConfig;

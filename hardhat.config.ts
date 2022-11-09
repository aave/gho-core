import { config } from 'dotenv';
import { HardhatUserConfig } from 'hardhat/types';
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from 'hardhat/builtin-tasks/task-names';
import { subtask } from 'hardhat/config';
import { DEFAULT_NAMED_ACCOUNTS } from '@aave/deploy-v3';

import '@typechain/hardhat';
import '@typechain/ethers-v5';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import 'hardhat-deploy';
import 'solidity-coverage';
import 'hardhat-contract-sizer';
import 'hardhat-gas-reporter';
import 'hardhat-dependency-compiler';

config();

import { accounts } from './src/helpers/test-wallets';

// Prevent to load tasks before compilation and typechain
if (!process.env.SKIP_LOAD) {
  require('./src/tasks/set-DRE');
  require('./src/tasks/deploy-v3');
  require('./src/tasks/setup/gho-setup');
  require('./src/tasks/setup/initialize-gho-reserve');
  require('./src/tasks/setup/set-gho-oracle');
  require('./src/tasks/setup/enable-gho-borrowing');
  require('./src/tasks/setup/add-gho-as-entity');
  require('./src/tasks/setup/add-gho-flashminter-as-entity');
  require('./src/tasks/setup/set-gho-addresses');
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
      // throwOnTransactionFailures: true,
      // throwOnCallFailures: true,
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
    ...DEFAULT_NAMED_ACCOUNTS,
  },
  typechain: {
    outDir: 'types',
    target: 'ethers-v5',
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    externalArtifacts: [], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
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
        artifacts: './temp-artifacts',
        deploy: 'node_modules/@aave/deploy-v3/dist/deploy',
      },
    ],
  },
  dependencyCompiler: {
    paths: [
      '@aave/core-v3/contracts/dependencies/chainlink/AggregatorInterface',
      '@aave/core-v3/contracts/misc/AaveOracle.sol',
      '@aave/core-v3/contracts/protocol/configuration/ACLManager.sol',
      '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/InitializableImmutableAdminUpgradeabilityProxy',
      '@aave/core-v3/contracts/protocol/tokenization/AToken.sol',
      '@aave/core-v3/contracts/protocol/tokenization/StableDebtToken.sol',
      '@aave/core-v3/contracts/protocol/tokenization/VariableDebtToken.sol',
      '@aave/core-v3/contracts/protocol/pool/Pool.sol',
      '@aave/core-v3/contracts/protocol/pool/PoolConfigurator.sol',
      '@aave/core-v3/contracts/misc/AaveProtocolDataProvider.sol',
      '@aave/core-v3/contracts/mocks/oracle/CLAggregators/MockAggregator.sol',
      '@aave/core-v3/contracts/mocks/tokens/MintableERC20.sol',
      '@aave/core-v3/contracts/mocks/oracle/PriceOracle.sol',
      '@aave/core-v3/contracts/mocks/tokens/MintableDelegationERC20.sol',
    ],
  },
  // tracer: {
  //   nameTags: {
  //     '0x58F132FBB86E21545A4Bace3C19f1C05d86d7A22': 'weth',
  //     '0x12080583C4F0211eC382d33a273E6D0f9fAb0F75': 'addresses_provider',
  //   },
  // },
};

export default hardhatConfig;

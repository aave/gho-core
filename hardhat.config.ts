import 'dotenv/config';

import { task } from 'hardhat/config';
import type { HardhatUserConfig } from 'hardhat/config';

import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-deploy';
import 'hardhat-dependency-compiler';
import 'solidity-coverage';

// Prevent to load tasks before compilation and typechain
if (!process.env.SKIP_LOAD) {
  require('./src/tasks/set-DRE');
  require('./src/tasks/setup/antei-setup');
  require('./src/tasks/setup/initialize-asd-reserve');
  require('./src/tasks/setup/set-asd-oracle');
  require('./src/tasks/setup/enable-asd-borrowing');
  require('./src/tasks/setup/add-asd-as-entity');
  require('./src/tasks/setup/set-asd-addresses');
}

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 14618850,
      },
    },
    localhost: {
      url: 'http://127.0.0.1:8545',
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 14618850,
      },
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.0',
      },
      {
        version: '0.7.0',
        settings: {},
      },
      {
        version: '0.6.12',
        settings: {},
      },
    ],
  },
  paths: {
    sources: './src/contracts/antei',
    tests: './src/test/',
    cache: './cache',
    artifacts: './artifacts',
  },
  dependencyCompiler: {
    paths: [
      '@aave/protocol-v2/contracts/protocol/lendingpool/LendingPoolConfigurator.sol',
      '@aave/protocol-v2/contracts/protocol/tokenization/AToken.sol',
      '@aave/protocol-v2/contracts/protocol/tokenization/VariableDebtToken.sol',
      '@aave/protocol-v2/contracts/protocol/tokenization/StableDebtToken.sol',
      '@aave/protocol-v2/contracts/misc/AaveProtocolDataProvider.sol',
      '@aave/protocol-v2/contracts/misc/AaveOracle.sol',
      '@aave/protocol-v2/contracts/protocol/libraries/aave-upgradeability/BaseImmutableAdminUpgradeabilityProxy.sol',
    ],
  },
  namedAccounts: {
    deployer: 0,
  },
  typechain: {
    outDir: 'types',
    target: 'ethers-v5',
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    externalArtifacts: ['@aave/protocol-v2/artifacts/contracts/**/*.json'], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
  },
};

export default config;

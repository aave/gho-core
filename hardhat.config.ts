import 'dotenv/config';

import { task } from 'hardhat/config';
import '@nomiclabs/hardhat-waffle';
import 'hardhat-dependency-compiler';
import type { HardhatUserConfig } from 'hardhat/config';

import './src/tasks/setup/deploy-antei-erc20';
import './src/tasks/setup/deploy-antei-atoken';
import './src/tasks/setup/deploy-antei-variable-debt';
import './src/tasks/setup/deploy-antei-stable-debt';
import './src/tasks/setup/deploy-antei-oracle';
import './src/tasks/setup/deploy-antei-interest-rate-strategy';
import './src/tasks/setup/antei-setup';
import './src/tasks/set-DRE';

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
      '@aave/protocol-v2/contracts/protocol/tokenization/AToken.sol',
      '@aave/protocol-v2/contracts/protocol/tokenization/VariableDebtToken.sol',
      '@aave/protocol-v2/contracts/protocol/tokenization/StableDebtToken.sol',
    ],
  },
};

export default config;

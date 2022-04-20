import { task } from 'hardhat/config';
import '@nomiclabs/hardhat-waffle';

import type { HardhatUserConfig } from 'hardhat/config';

import './src/tasks/deploy-antei-token';
import './src/tasks/set-DRE';

require('dotenv').config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
// types

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
    ],
  },
  paths: {
    sources: './src/contracts/antei',
    tests: './src/test/',
    cache: './cache',
    artifacts: './artifacts',
  },
};

export default config;

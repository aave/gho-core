const accounts = require(`./src/helpers/test-wallets.ts`).accounts;
const cp = require('child_process');

module.exports = {
  client: require('ganache-cli'),
  skipFiles: ['dependencies/', 'interfaces/', 'poolUpgrade/', 'stkAaveUpgrade/'],
  mocha: {
    enableTimeouts: false,
  },
  configureYulOptimizer: true,
};

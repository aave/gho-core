module.exports = {
  skipFiles: [
    'test/',
    'facilitators/aave/dependencies',
    'facilitators/aave/mocks',
    'facilitators/aave/poolUpgrade/',
    'facilitators/aave/stkAaveUpgrade/',
    'facilitators/flashMinter/mocks',
    'foundry-test/',
  ],
  mocha: {
    enableTimeouts: false,
  },
  configureYulOptimizer: true,
};

module.exports = {
  skipFiles: [
    'test/',
    'facilitators/aave/dependencies',
    'facilitators/aave/mocks',
    'facilitators/aave/poolUpgrade/',
    'facilitators/aave/stkAaveUpgrade/',
    'facilitators/flashMinter/mocks',
  ],
  mocha: {
    enableTimeouts: false,
  },
  configureYulOptimizer: true,
};

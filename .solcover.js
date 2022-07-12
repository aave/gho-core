module.exports = {
  skipFiles: [
    'test/',
    'facilitators/aave/dependencies',
    'facilitators/aave/poolUpgrade/',
    'facilitators/aave/stkAaveUpgrade/',
  ],
  mocha: {
    enableTimeouts: false,
  },
  configureYulOptimizer: true,
};

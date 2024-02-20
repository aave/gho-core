module.exports = {
  skipFiles: ['./script', './test'],
  mocha: {
    enableTimeouts: false,
  },
  configureYulOptimizer: true,
};

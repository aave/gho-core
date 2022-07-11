module.exports = {
  skipFiles: ['dependencies/', 'interfaces/', 'poolUpgrade/', 'stkAaveUpgrade/'],
  mocha: {
    enableTimeouts: false,
  },
  configureYulOptimizer: true,
};

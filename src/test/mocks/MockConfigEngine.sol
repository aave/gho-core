// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MockConfigEngine {
  constructor() {}

  struct InterestRateInputData {
    uint256 optimalUsageRatio;
    uint256 baseVariableBorrowRate;
    uint256 variableRateSlope1;
    uint256 variableRateSlope2;
  }

  struct RateStrategyUpdate {
    address asset;
    InterestRateInputData params;
  }

  function updateRateStrategies(RateStrategyUpdate[] calldata updates) external {}
}

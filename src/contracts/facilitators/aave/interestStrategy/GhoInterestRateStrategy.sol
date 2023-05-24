// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {IReserveInterestRateStrategy} from '@aave/core-v3/contracts/interfaces/IReserveInterestRateStrategy.sol';

/**
 * @title GhoInterestRateStrategy
 * @author Aave
 * @notice Implements the calculation of GHO interest rates
 * @dev The variable borrow interest rate is fixed at deployment time.
 */
contract GhoInterestRateStrategy is IReserveInterestRateStrategy {
  // Variable borrow rate (expressed in ray)
  uint256 public immutable VARIABLE_BORROW_RATE;

  /**
   * @dev Constructor
   * @param variableBorrowRate The variable borrow rate (expressed in ray)
   */
  constructor(uint256 variableBorrowRate) {
    VARIABLE_BORROW_RATE = variableBorrowRate;
  }

  /// @inheritdoc IReserveInterestRateStrategy
  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory params
  ) public view override returns (uint256, uint256, uint256) {
    return (0, 0, VARIABLE_BORROW_RATE);
  }
}

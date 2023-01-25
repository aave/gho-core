// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

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
  uint256 internal immutable _variableBorrowRate;

  /**
   * @dev Constructor
   * @param variableBorrowRate The variable borrow rate (expressed in ray)
   */
  constructor(uint256 variableBorrowRate) {
    _variableBorrowRate = variableBorrowRate;
  }

  /// @inheritdoc IReserveInterestRateStrategy
  function calculateInterestRates(DataTypes.CalculateInterestRatesParams memory params)
    public
    view
    override
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    return (1e25, 1e25, _variableBorrowRate);
  }
}

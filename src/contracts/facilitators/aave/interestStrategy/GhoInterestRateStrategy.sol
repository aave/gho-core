// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {IDefaultInterestRateStrategy} from '@aave/core-v3/contracts/interfaces/IDefaultInterestRateStrategy.sol';
import {IReserveInterestRateStrategy} from '@aave/core-v3/contracts/interfaces/IReserveInterestRateStrategy.sol';
import {IPoolAddressesProvider} from '@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title GhoInterestRateStrategy
 * @author Aave
 * @notice Implements the calculation of GHO interest rates
 * @dev The variable borrow interest rate is fixed at deployment time.
 */
contract GhoInterestRateStrategy is IDefaultInterestRateStrategy {
  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant OPTIMAL_USAGE_RATIO = 0;

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO = 0;

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant MAX_EXCESS_USAGE_RATIO = 0;

  /// @inheritdoc IDefaultInterestRateStrategy
  uint256 public constant MAX_EXCESS_STABLE_TO_TOTAL_DEBT_RATIO = 0;

  /// @inheritdoc IDefaultInterestRateStrategy
  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;

  // Base variable borrow rate when usage rate = 0. Expressed in ray
  uint256 internal immutable _baseVariableBorrowRate;

  // Slope of the variable interest curve when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO. Expressed in ray
  uint256 internal constant _variableRateSlope1 = 0;

  // Slope of the variable interest curve when usage ratio > OPTIMAL_USAGE_RATIO. Expressed in ray
  uint256 internal constant _variableRateSlope2 = 0;

  // Slope of the stable interest curve when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO. Expressed in ray
  uint256 internal constant _stableRateSlope1 = 0;

  // Slope of the stable interest curve when usage ratio > OPTIMAL_USAGE_RATIO. Expressed in ray
  uint256 internal constant _stableRateSlope2 = 0;

  // Premium on top of `_variableRateSlope1` for base stable borrowing rate
  uint256 internal constant _baseStableRateOffset = 0;

  // Additional premium applied to stable rate when stable debt surpass `OPTIMAL_STABLE_TO_TOTAL_DEBT_RATIO`
  uint256 internal constant _stableRateExcessOffset = 0;

  /**
   * @dev Constructor
   * @param addressesProvider The address of the PoolAddressesProvider
   * @param borrowRate The variable borrow rate (expressed in ray)
   */
  constructor(address addressesProvider, uint256 borrowRate) {
    ADDRESSES_PROVIDER = IPoolAddressesProvider(addressesProvider);
    _baseVariableBorrowRate = borrowRate;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getVariableRateSlope1() external pure returns (uint256) {
    return _variableRateSlope1;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getVariableRateSlope2() external pure returns (uint256) {
    return _variableRateSlope2;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getStableRateSlope1() external pure returns (uint256) {
    return _stableRateSlope1;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getStableRateSlope2() external pure returns (uint256) {
    return _stableRateSlope2;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getStableRateExcessOffset() external pure returns (uint256) {
    return _stableRateExcessOffset;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getBaseStableBorrowRate() public pure returns (uint256) {
    return _variableRateSlope1 + _baseStableRateOffset;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getBaseVariableBorrowRate() external view override returns (uint256) {
    return _baseVariableBorrowRate;
  }

  /// @inheritdoc IDefaultInterestRateStrategy
  function getMaxVariableBorrowRate() external view override returns (uint256) {
    return _baseVariableBorrowRate;
  }

  /// @inheritdoc IReserveInterestRateStrategy
  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory
  ) public view override returns (uint256, uint256, uint256) {
    return (0, 0, _baseVariableBorrowRate);
  }
}

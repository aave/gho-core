// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {IGsmFeeStrategy} from './interfaces/IGsmFeeStrategy.sol';

/**
 * @title FixedFeeStrategy
 * @author Aave
 * @notice Fee strategy using a fixed rate to calculate buy/sell fees
 */
contract FixedFeeStrategy is IGsmFeeStrategy {
  using PercentageMath for uint256;

  uint256 internal immutable _buyFee;
  uint256 internal immutable _sellFee;

  /**
   * @dev Constructor
   * @param buyFee The fee paid when supplying collateral for GHO, expressed in bps
   * @param sellFee The fee paid when selling GHO for collateral, expressed in bps
   */
  constructor(uint256 buyFee, uint256 sellFee) {
    require(buyFee <= PercentageMath.PERCENTAGE_FACTOR, 'INVALID_BUY_FEE');
    require(sellFee <= PercentageMath.PERCENTAGE_FACTOR, 'INVALID_SELL_FEE');
    _buyFee = buyFee;
    _sellFee = sellFee;
  }

  /// @inheritdoc IGsmFeeStrategy
  function getBuyFee(uint256 grossAmount) external view returns (uint256) {
    return grossAmount.percentMul(_buyFee);
  }

  /// @inheritdoc IGsmFeeStrategy
  function getSellFee(uint256 grossAmount) external view returns (uint256) {
    return grossAmount.percentMul(_sellFee);
  }

  /// @inheritdoc IGsmFeeStrategy
  function getGrossAmountFromTotalBought(uint256 totalAmount) external view returns (uint256) {
    if (totalAmount == 0) {
      return 0;
    } else if (_buyFee == 0) {
      return totalAmount;
    } else {
      return totalAmount.percentDiv(PercentageMath.PERCENTAGE_FACTOR + _buyFee);
    }
  }

  /// @inheritdoc IGsmFeeStrategy
  function getGrossAmountFromTotalSold(uint256 totalAmount) external view returns (uint256) {
    if (totalAmount == 0) {
      return 0;
    } else if (_sellFee == 0) {
      return totalAmount;
    } else if (_sellFee == PercentageMath.PERCENTAGE_FACTOR) {
      return totalAmount / 2;
    } else {
      return totalAmount.percentDiv(PercentageMath.PERCENTAGE_FACTOR - _sellFee);
    }
  }
}

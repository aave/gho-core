// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';
import {IGsmFeeStrategy} from './interfaces/IGsmFeeStrategy.sol';

/**
 * @title FixedFeeStrategy
 * @author Aave
 * @notice Fee strategy using a fixed rate to calculate buy/sell fees
 */
contract FixedFeeStrategy is IGsmFeeStrategy {
  using Math for uint256;

  uint256 internal immutable _buyFee;
  uint256 internal immutable _sellFee;

  /**
   * @dev Constructor
   * @dev Fees must be lower than 5000 bps (e.g. 50.00%)
   * @param buyFee The fee paid when buying the underlying asset in exchange for GHO, expressed in bps
   * @param sellFee The fee paid when selling the underlying asset in exchange for GHO, expressed in bps
   */
  constructor(uint256 buyFee, uint256 sellFee) {
    require(buyFee < 5000, 'INVALID_BUY_FEE');
    require(sellFee < 5000, 'INVALID_SELL_FEE');
    require(buyFee > 0 || sellFee > 0, 'MUST_HAVE_ONE_NONZERO_FEE');
    _buyFee = buyFee;
    _sellFee = sellFee;
  }

  /// @inheritdoc IGsmFeeStrategy
  function getBuyFee(uint256 grossAmount) external view returns (uint256) {
    return grossAmount.mulDiv(_buyFee, PercentageMath.PERCENTAGE_FACTOR, Math.Rounding.Up);
  }

  /// @inheritdoc IGsmFeeStrategy
  function getSellFee(uint256 grossAmount) external view returns (uint256) {
    return grossAmount.mulDiv(_sellFee, PercentageMath.PERCENTAGE_FACTOR, Math.Rounding.Up);
  }

  /// @inheritdoc IGsmFeeStrategy
  function getGrossAmountFromTotalBought(uint256 totalAmount) external view returns (uint256) {
    if (totalAmount == 0) {
      return 0;
    } else if (_buyFee == 0) {
      return totalAmount;
    } else {
      return
        totalAmount.mulDiv(
          PercentageMath.PERCENTAGE_FACTOR,
          /// BinaryOpMutation of: PercentageMath.PERCENTAGE_FACTOR + _buyFee,
          PercentageMath.PERCENTAGE_FACTOR / _buyFee,
          Math.Rounding.Down
        );
    }
  }

  /// @inheritdoc IGsmFeeStrategy
  function getGrossAmountFromTotalSold(uint256 totalAmount) external view returns (uint256) {
    if (totalAmount == 0) {
      return 0;
    } else if (_sellFee == 0) {
      return totalAmount;
    } else {
      return
        totalAmount.mulDiv(
          PercentageMath.PERCENTAGE_FACTOR,
          PercentageMath.PERCENTAGE_FACTOR - _sellFee,
          Math.Rounding.Up
        );
    }
  }
}

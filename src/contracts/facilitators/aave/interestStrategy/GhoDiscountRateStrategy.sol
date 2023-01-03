// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

import {WadRayMath} from '@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol';
import {IGhoDiscountRateStrategy} from '../tokens/interfaces/IGhoDiscountRateStrategy.sol';

/**
 * @title GhoDiscountRateStrategy contract
 * @author Aave
 * @notice Implements the calculation of the discount rate depending on the current strategy
 */
contract GhoDiscountRateStrategy is IGhoDiscountRateStrategy {
  using WadRayMath for uint256;

  /**
   * @dev Amount of debt that is entitled to get a discount per unit of discount token
   * Expressed with the number of decimals of the discount token
   */
  uint256 public constant GHO_DISCOUNTED_PER_DISCOUNT_TOKEN = 100e18;

  /**
   * @dev Percentage of discount to apply to the part of the debt that is entitled to get a discount
   * Expressed in bps, a value of 2000 results in 20.00%
   */
  uint256 public constant DISCOUNT_RATE = 2000;

  /**
   * @dev Minimum balance amount of discount token to be entitled to a discount
   * Expressed with the number of decimals of the discount token
   */
  uint256 public constant MIN_DISCOUNT_TOKEN_BALANCE = 1e18;

  /**
   * @dev Minimum balance amount of debt token to be entitled to a discount
   * Expressed with the number of decimals of the debt token
   */
  uint256 public constant MIN_DEBT_TOKEN_BALANCE = 1e18;

  /// @inheritdoc IGhoDiscountRateStrategy
  function calculateDiscountRate(uint256 debtBalance, uint256 discountTokenBalance)
    external
    pure
    override
    returns (uint256)
  {
    if (discountTokenBalance < MIN_DISCOUNT_TOKEN_BALANCE || debtBalance < MIN_DEBT_TOKEN_BALANCE) {
      return 0;
    } else {
      uint256 discountedBalance = discountTokenBalance.wadMul(GHO_DISCOUNTED_PER_DISCOUNT_TOKEN);
      if (discountedBalance >= debtBalance) {
        return DISCOUNT_RATE;
      } else {
        return (discountedBalance * DISCOUNT_RATE) / debtBalance;
      }
    }
  }
}

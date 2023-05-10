// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IGhoDiscountRateStrategy} from '../interestStrategy/interfaces/IGhoDiscountRateStrategy.sol';

/**
 * @title ZeroDiscountRateStrategy
 * @author Aave
 * @notice Discount Rate Strategy that always return zero discount rate.
 */
contract ZeroDiscountRateStrategy is IGhoDiscountRateStrategy {
  /**
   * @dev Calculates the interest rates depending on the reserve's state and configurations
   * @param debtBalance The address of the reserve
   * @param discountTokenBalance The liquidity available in the reserve
   * @return The discount rate, as a percentage - the maximum can be 10000 = 100.00%
   */
  function calculateDiscountRate(
    uint256 debtBalance,
    uint256 discountTokenBalance
  ) external view override returns (uint256) {
    return 0;
  }
}

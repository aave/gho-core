// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IGhoDiscountRateStrategy} from '../interestStrategy/interfaces/IGhoDiscountRateStrategy.sol';

/**
 * @title ZeroDiscountRateStrategy
 * @author Aave
 * @notice Discount Rate Strategy that always return zero discount rate.
 */
contract ZeroDiscountRateStrategy is IGhoDiscountRateStrategy {
  /// @inheritdoc IGhoDiscountRateStrategy
  function calculateDiscountRate(
    uint256 debtBalance,
    uint256 discountTokenBalance
  ) external view override returns (uint256) {
    return 0;
  }
}

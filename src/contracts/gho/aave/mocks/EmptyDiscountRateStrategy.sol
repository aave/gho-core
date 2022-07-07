// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IGhoDiscountRateStrategy} from '../tokens/interfaces/IGhoDiscountRateStrategy.sol';

contract EmptyDiscountRateStrategy is IGhoDiscountRateStrategy {
  /**
   * @dev Calculates the interest rates depending on the reserve's state and configurations
   * @param debtBalance The address of the reserve
   * @param discountTokenBalance The liquidity available in the reserve
   * @return The discount rate, as a percentage - the maximum can be 10000 = 100.00%
   **/
  function calculateDiscountRate(uint256 debtBalance, uint256 discountTokenBalance)
    external
    view
    override
    returns (uint256)
  {
    return 0;
  }
}

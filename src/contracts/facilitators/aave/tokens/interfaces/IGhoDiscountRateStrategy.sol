// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

interface IGhoDiscountRateStrategy {
  /**
   * @dev Calculates the interest rates depending on the reserve's state and configurations
   * @param debtBalance The address of the reserve
   * @param discountTokenBalance The liquidity available in the reserve
   * @return The discount rate, as a percentage - the maximum can be 10000 = 100.00%
   **/
  function calculateDiscountRate(uint256 debtBalance, uint256 discountTokenBalance)
    external
    view
    returns (uint256);
}

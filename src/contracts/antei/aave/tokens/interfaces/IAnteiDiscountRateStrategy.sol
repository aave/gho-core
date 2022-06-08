// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

interface IAnteiDiscountRateStrategy {
  /**
   * @dev Calculates the interest rates depending on the reserve's state and configurations
   * @param debtBalance The address of the reserve
   * @param stakedTokenBalance The liquidity available in the reserve
   * @return The discount rate, as a percentage - the maximum can be 10000 = 100.00%
   **/
  function calculateDiscountRate(uint256 debtBalance, uint256 stakedTokenBalance)
    external
    view
    returns (uint256);
}

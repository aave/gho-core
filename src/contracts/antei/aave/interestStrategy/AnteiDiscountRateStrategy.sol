// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {SafeMath} from '../../dependencies/aave-core/dependencies/openzeppelin/contracts/SafeMath.sol';
import {WadRayMath} from '../../dependencies/aave-core/protocol/libraries/math/WadRayMath.sol';
import {PercentageMath} from '../../dependencies/aave-core/protocol/libraries/math/PercentageMath.sol';
import {IAnteiDiscountRateStrategy} from '../tokens/interfaces/IAnteiDiscountRateStrategy.sol';

/**
 * @title AnteiDiscountRateStrategy contract
 * @notice Implements the calculation of the discount rate depending on the current strategy
 * @author Aave
 **/
contract AnteiDiscountRateStrategy is IAnteiDiscountRateStrategy {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using SafeMath for uint256;

  uint256 public tokensDiscountedPerStkAave = 100e18;
  uint256 public discountRate = 2000;
  uint256 public minDiscountTokenBalance = 1e18;

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
    if (discountTokenBalance < minDiscountTokenBalance || debtBalance == 0) {
      return 0;
    } else {
      uint256 discountedBalance = discountTokenBalance.wadMul(tokensDiscountedPerStkAave);
      if (discountedBalance >= debtBalance) {
        return discountRate;
      } else {
        // intentionally skip checked division
        return discountedBalance.percentMul(discountRate) / debtBalance;
      }
    }
  }
}

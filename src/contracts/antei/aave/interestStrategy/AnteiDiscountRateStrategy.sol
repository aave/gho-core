// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {SafeMath} from '../../dependencies/aave-core/dependencies/openzeppelin/contracts/SafeMath.sol';
import {WadRayMath} from '../../dependencies/aave-core/protocol/libraries/math/WadRayMath.sol';
import {IAnteiDiscountRateStrategy} from '../tokens/interfaces/IAnteiDiscountRateStrategy.sol';

/**
 * @title AnteiDiscountRateStrategy contract
 * @notice Implements the calculation of the discount rate depending on the current strategy
 * @author Aave
 **/
contract AnteiDiscountRateStrategy is IAnteiDiscountRateStrategy {
  using WadRayMath for uint256;
  using SafeMath for uint256;

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
    if (discountTokenBalance > 1e18) {
      return 2000;
    } else {
      return 0;
    }
  }
}

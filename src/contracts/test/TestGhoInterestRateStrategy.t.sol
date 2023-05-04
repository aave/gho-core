// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import './TestGhoBase.t.sol';

contract TestGhoInterestRateStrategy is TestGhoBase {
  function testFuzzConstructor(
    uint256 variableBorrowRate,
    DataTypes.CalculateInterestRatesParams memory params
  ) public {
    GhoInterestRateStrategy ghoInterest = new GhoInterestRateStrategy(variableBorrowRate);
    (uint256 x, uint256 y, uint256 z) = ghoInterest.calculateInterestRates(params);
    assertEq(x, 0, 'Unexpected first return value in interest rate');
    assertEq(y, 0, 'Unexpected second return value in interest rate');
    assertEq(z, variableBorrowRate, 'Unexpected variable borrow rate');
  }
}

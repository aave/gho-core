// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoInterestRateStrategy is TestGhoBase {
  function testFuzzVariableRateSetOnly(
    address addressesProvider,
    uint256 variableBorrowRate,
    DataTypes.CalculateInterestRatesParams memory params
  ) public {
    GhoInterestRateStrategy ghoInterest = new GhoInterestRateStrategy(
      addressesProvider,
      variableBorrowRate
    );
    assertEq(address(ghoInterest.ADDRESSES_PROVIDER()), addressesProvider);
    assertEq(ghoInterest.getBaseVariableBorrowRate(), variableBorrowRate);
    assertEq(ghoInterest.getMaxVariableBorrowRate(), variableBorrowRate);
    (uint256 x, uint256 y, uint256 z) = ghoInterest.calculateInterestRates(params);
    assertEq(x, 0, 'Unexpected first return value in interest rate');
    assertEq(y, 0, 'Unexpected second return value in interest rate');
    assertEq(z, variableBorrowRate, 'Unexpected variable borrow rate');
  }
}

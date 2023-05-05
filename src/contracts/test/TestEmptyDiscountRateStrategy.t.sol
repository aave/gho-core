// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import './TestGhoBase.t.sol';

import {EmptyDiscountRateStrategy} from '../facilitators/aave/mocks/EmptyDiscountRateStrategy.sol';

contract TestEmptyDiscountRateStrategy is TestGhoBase {
  EmptyDiscountRateStrategy emptyStrategy;

  function setUp() public {
    emptyStrategy = new EmptyDiscountRateStrategy();
  }

  function testFuzzRateAlwaysZero(uint256 debtBalance, uint256 discountTokenBalance) public {
    uint256 result = emptyStrategy.calculateDiscountRate(debtBalance, discountTokenBalance);
    assertEq(result, 0, 'Unexpected discount rate');
  }
}

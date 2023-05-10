// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

import {ZeroDiscountRateStrategy} from '../contracts/facilitators/aave/interestStrategy/ZeroDiscountRateStrategy.sol';

contract TestZeroDiscountRateStrategy is TestGhoBase {
  ZeroDiscountRateStrategy emptyStrategy;

  function setUp() public {
    emptyStrategy = new ZeroDiscountRateStrategy();
  }

  function testFuzzRateAlwaysZero(uint256 debtBalance, uint256 discountTokenBalance) public {
    uint256 result = emptyStrategy.calculateDiscountRate(debtBalance, discountTokenBalance);
    assertEq(result, 0, 'Unexpected discount rate');
  }
}

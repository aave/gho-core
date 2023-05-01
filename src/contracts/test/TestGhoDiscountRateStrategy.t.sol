// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import './TestGhoBase.t.sol';

contract TestGhoDiscountRateStrategy is TestGhoBase {
  using WadRayMath for uint256;

  uint256 maxDiscountBalance;

  function setUp() public {
    // Calculate actual maximum value for discountTokenBalance based on wadMul usage
    maxDiscountBalance =
      (UINT256_MAX / GHO_DISCOUNT_STRATEGY.GHO_DISCOUNTED_PER_DISCOUNT_TOKEN()) -
      WadRayMath.HALF_WAD;
  }

  function testDebtBalanceBelowThreshold() public {
    uint256 result = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
      0,
      GHO_DISCOUNT_STRATEGY.MIN_DISCOUNT_TOKEN_BALANCE()
    );
    assertEq(result, 0, 'Unexpected discount rate');
  }

  function testDiscountBalanceBelowThreshold() public {
    uint256 result = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
      GHO_DISCOUNT_STRATEGY.MIN_DEBT_TOKEN_BALANCE(),
      0
    );
    assertEq(result, 0, 'Unexpected discount rate');
  }

  function testMoreDiscountTokenThanDebtRate() public {
    assertGe(
      GHO_DISCOUNT_STRATEGY.GHO_DISCOUNTED_PER_DISCOUNT_TOKEN(),
      1e18,
      'Unexpected low value for discount token conversion'
    );
    assertGe(
      GHO_DISCOUNT_STRATEGY.MIN_DISCOUNT_TOKEN_BALANCE(),
      GHO_DISCOUNT_STRATEGY.MIN_DEBT_TOKEN_BALANCE(),
      'Invalid assumption that discount token balance at least debt token balance'
    );
    uint256 result = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
      GHO_DISCOUNT_STRATEGY.MIN_DEBT_TOKEN_BALANCE(),
      GHO_DISCOUNT_STRATEGY.MIN_DISCOUNT_TOKEN_BALANCE()
    );
    assertEq(result, GHO_DISCOUNT_STRATEGY.DISCOUNT_RATE(), 'Unexpected discount rate');
  }

  function testLessDiscountTokenThanDebtRate() public {
    assertGe(
      GHO_DISCOUNT_STRATEGY.GHO_DISCOUNTED_PER_DISCOUNT_TOKEN(),
      1e18,
      'Unexpected low value for discount token conversion'
    );
    assertGe(
      GHO_DISCOUNT_STRATEGY.MIN_DISCOUNT_TOKEN_BALANCE(),
      GHO_DISCOUNT_STRATEGY.MIN_DEBT_TOKEN_BALANCE(),
      'Invalid assumption that discount token balance at least debt token balance'
    );

    uint256 debtBalance = GHO_DISCOUNT_STRATEGY.MIN_DISCOUNT_TOKEN_BALANCE().wadMul(
      GHO_DISCOUNT_STRATEGY.GHO_DISCOUNTED_PER_DISCOUNT_TOKEN()
    ) + 1;

    uint256 result = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
      debtBalance,
      GHO_DISCOUNT_STRATEGY.MIN_DISCOUNT_TOKEN_BALANCE()
    );
    assertLt(result, GHO_DISCOUNT_STRATEGY.DISCOUNT_RATE(), 'Unexpected discount rate');
  }

  function testFuzzMinBalance(uint256 debtBalance, uint256 discountTokenBalance) public {
    vm.assume(
      debtBalance < GHO_DISCOUNT_STRATEGY.MIN_DEBT_TOKEN_BALANCE() ||
        discountTokenBalance < GHO_DISCOUNT_STRATEGY.MIN_DISCOUNT_TOKEN_BALANCE()
    );
    uint256 result = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(debtBalance, discountTokenBalance);
    assertEq(result, 0, 'Minimum balance not zero');
  }

  function testFuzzNeverExceedHundredDiscount(
    uint256 debtBalance,
    uint256 discountTokenBalance
  ) public {
    vm.assume(
      (debtBalance >= GHO_DISCOUNT_STRATEGY.MIN_DEBT_TOKEN_BALANCE() ||
        discountTokenBalance >= GHO_DISCOUNT_STRATEGY.MIN_DISCOUNT_TOKEN_BALANCE()) &&
        discountTokenBalance < maxDiscountBalance
    );
    uint256 result = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(debtBalance, discountTokenBalance);
    assertLe(result, 10000, 'Discount rate higher than 100%');
  }

  function testFuzzNeverExceedDiscountRate(
    uint256 debtBalance,
    uint256 discountTokenBalance
  ) public {
    vm.assume(
      (debtBalance >= GHO_DISCOUNT_STRATEGY.MIN_DEBT_TOKEN_BALANCE() ||
        discountTokenBalance >= GHO_DISCOUNT_STRATEGY.MIN_DISCOUNT_TOKEN_BALANCE()) &&
        discountTokenBalance < maxDiscountBalance
    );
    uint256 result = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(debtBalance, discountTokenBalance);
    assertLe(result, GHO_DISCOUNT_STRATEGY.DISCOUNT_RATE(), 'Discount rate higher than 100%');
  }
}

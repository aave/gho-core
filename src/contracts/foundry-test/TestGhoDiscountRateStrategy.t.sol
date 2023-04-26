// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import './TestEnv.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {DebtUtils} from './libraries/DebtUtils.sol';
import {GhoActions} from './libraries/GhoActions.sol';
import {WadRayMath} from '@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol';

contract TestGhoDiscountRateStrategy is Test, GhoActions {
  using WadRayMath for uint256;

  GhoDiscountRateStrategy ghoDiscount;
  uint256 maxDiscountBalance;

  function setUp() public {
    ghoDiscount = new GhoDiscountRateStrategy();
    // Calculate actual maximum value for discountTokenBalance based on wadMul usage
    maxDiscountBalance =
      (UINT256_MAX / ghoDiscount.GHO_DISCOUNTED_PER_DISCOUNT_TOKEN()) -
      WadRayMath.HALF_WAD;
  }

  function testDebtBalanceBelowThreshold() public {
    uint256 result = ghoDiscount.calculateDiscountRate(0, ghoDiscount.MIN_DISCOUNT_TOKEN_BALANCE());
    assertEq(result, 0, 'Unexpected discount rate');
  }

  function testDiscountBalanceBelowThreshold() public {
    uint256 result = ghoDiscount.calculateDiscountRate(ghoDiscount.MIN_DEBT_TOKEN_BALANCE(), 0);
    assertEq(result, 0, 'Unexpected discount rate');
  }

  function testMoreDiscountTokenThanDebtRate() public {
    assertGe(
      ghoDiscount.GHO_DISCOUNTED_PER_DISCOUNT_TOKEN(),
      1e18,
      'Unexpected low value for discount token conversion'
    );
    assertGe(
      ghoDiscount.MIN_DISCOUNT_TOKEN_BALANCE(),
      ghoDiscount.MIN_DEBT_TOKEN_BALANCE(),
      'Invalid assumption that discount token balance at least debt token balance'
    );
    uint256 result = ghoDiscount.calculateDiscountRate(
      ghoDiscount.MIN_DEBT_TOKEN_BALANCE(),
      ghoDiscount.MIN_DISCOUNT_TOKEN_BALANCE()
    );
    assertEq(result, ghoDiscount.DISCOUNT_RATE(), 'Unexpected discount rate');
  }

  function testLessDiscountTokenThanDebtRate() public {
    assertGe(
      ghoDiscount.GHO_DISCOUNTED_PER_DISCOUNT_TOKEN(),
      1e18,
      'Unexpected low value for discount token conversion'
    );
    assertGe(
      ghoDiscount.MIN_DISCOUNT_TOKEN_BALANCE(),
      ghoDiscount.MIN_DEBT_TOKEN_BALANCE(),
      'Invalid assumption that discount token balance at least debt token balance'
    );

    uint256 debtBalance = ghoDiscount.MIN_DISCOUNT_TOKEN_BALANCE().wadMul(
      ghoDiscount.GHO_DISCOUNTED_PER_DISCOUNT_TOKEN()
    ) + 1;

    uint256 result = ghoDiscount.calculateDiscountRate(
      debtBalance,
      ghoDiscount.MIN_DISCOUNT_TOKEN_BALANCE()
    );
    assertLt(result, ghoDiscount.DISCOUNT_RATE(), 'Unexpected discount rate');
  }

  function testFuzzMinBalance(uint256 debtBalance, uint256 discountTokenBalance) public {
    vm.assume(
      debtBalance < ghoDiscount.MIN_DEBT_TOKEN_BALANCE() ||
        discountTokenBalance < ghoDiscount.MIN_DISCOUNT_TOKEN_BALANCE()
    );
    uint256 result = ghoDiscount.calculateDiscountRate(debtBalance, discountTokenBalance);
    assertEq(result, 0, 'Minimum balance not zero');
  }

  function testFuzzNeverExceedHundredDiscount(
    uint256 debtBalance,
    uint256 discountTokenBalance
  ) public {
    vm.assume(
      (debtBalance >= ghoDiscount.MIN_DEBT_TOKEN_BALANCE() ||
        discountTokenBalance >= ghoDiscount.MIN_DISCOUNT_TOKEN_BALANCE()) &&
        discountTokenBalance < maxDiscountBalance
    );
    uint256 result = ghoDiscount.calculateDiscountRate(debtBalance, discountTokenBalance);
    assertLe(result, 10000, 'Discount rate higher than 100%');
  }

  function testFuzzNeverExceedDiscountRate(
    uint256 debtBalance,
    uint256 discountTokenBalance
  ) public {
    vm.assume(
      (debtBalance >= ghoDiscount.MIN_DEBT_TOKEN_BALANCE() ||
        discountTokenBalance >= ghoDiscount.MIN_DISCOUNT_TOKEN_BALANCE()) &&
        discountTokenBalance < maxDiscountBalance
    );
    uint256 result = ghoDiscount.calculateDiscountRate(debtBalance, discountTokenBalance);
    assertLe(result, ghoDiscount.DISCOUNT_RATE(), 'Discount rate higher than 100%');
  }
}

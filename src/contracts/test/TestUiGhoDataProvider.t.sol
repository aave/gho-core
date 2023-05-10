// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

import {UiGhoDataProvider, IUiGhoDataProvider} from '../facilitators/aave/misc/UiGhoDataProvider.sol';

contract TestUiGhoDataProvider is TestGhoBase {
  UiGhoDataProvider dataProvider;

  function setUp() public {
    dataProvider = new UiGhoDataProvider(IPool(POOL), GHO_TOKEN);
  }

  function testGhoReserveData() public {
    DataTypes.ReserveData memory baseData = POOL.getReserveData(address(GHO_TOKEN));
    (uint256 bucketCapacity, uint256 bucketLevel) = GHO_TOKEN.getFacilitatorBucket(
      baseData.aTokenAddress
    );
    IUiGhoDataProvider.GhoReserveData memory result = dataProvider.getGhoReserveData();
    assertEq(
      result.ghoBaseVariableBorrowRate,
      baseData.currentVariableBorrowRate,
      'Unexpected variable borrow rate'
    );
    assertEq(
      result.ghoDiscountedPerToken,
      GHO_DISCOUNT_STRATEGY.GHO_DISCOUNTED_PER_DISCOUNT_TOKEN(),
      'Unexpected discount per token'
    );
    assertEq(
      result.ghoDiscountRate,
      GHO_DISCOUNT_STRATEGY.DISCOUNT_RATE(),
      'Unexpected discount rate'
    );
    assertEq(
      result.ghoMinDebtTokenBalanceForDiscount,
      GHO_DISCOUNT_STRATEGY.MIN_DISCOUNT_TOKEN_BALANCE(),
      'Unexpected minimum discount token balance'
    );
    assertEq(
      result.ghoMinDiscountTokenBalanceForDiscount,
      GHO_DISCOUNT_STRATEGY.MIN_DEBT_TOKEN_BALANCE(),
      'Unexpected minimum debt token balance'
    );
    assertEq(
      result.ghoReserveLastUpdateTimestamp,
      baseData.lastUpdateTimestamp,
      'Unexpected last timestamp'
    );
    assertEq(result.ghoCurrentBorrowIndex, baseData.variableBorrowIndex, 'Unexpected borrow index');
    assertEq(result.aaveFacilitatorBucketLevel, bucketLevel, 'Unexpected facilitator bucket level');
    assertEq(
      result.aaveFacilitatorBucketMaxCapacity,
      bucketCapacity,
      'Unexpected facilitator bucket capacity'
    );
  }

  function testGhoUserData() public {
    IUiGhoDataProvider.GhoUserData memory result = dataProvider.getGhoUserData(ALICE);
    assertEq(
      result.userGhoDiscountPercent,
      GHO_DEBT_TOKEN.getDiscountPercent(ALICE),
      'Unexpected discount percent'
    );
    assertEq(
      result.userDiscountTokenBalance,
      IERC20(GHO_DEBT_TOKEN.getDiscountToken()).balanceOf(ALICE),
      'Unexpected discount token balance'
    );
    assertEq(
      result.userPreviousGhoBorrowIndex,
      GHO_DEBT_TOKEN.getPreviousIndex(ALICE),
      'Unexpected previous index'
    );
    assertEq(
      result.userGhoScaledBorrowBalance,
      GHO_DEBT_TOKEN.scaledBalanceOf(ALICE),
      'Unexpected scaled balance'
    );
  }
}

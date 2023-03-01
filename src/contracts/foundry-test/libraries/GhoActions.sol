// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import '../TestEnv.sol';
import {DebtUtils} from '../libraries/DebtUtils.sol';
import {SafeCast} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/SafeCast.sol';
import {WadRayMath} from '@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol';
import {PercentageMath} from '@aave/core-v3/contracts/protocol/libraries/math/PercentageMath.sol';

contract GhoActions is Test, TestEnv {
  using WadRayMath for uint256;
  using SafeCast for uint256;
  using PercentageMath for uint256;

  struct BorrowState {
    uint256 supplyBeforeAction;
    uint256 debtSupplyBeforeAction;
    uint256 debtScaledSupplyBeforeAction;
    uint256 balanceBeforeAction;
    uint256 debtScaledBalanceBeforeAction;
    uint256 debtBalanceBeforeAction;
    uint256 userIndexBeforeAction;
    uint256 userInterestsBeforeAction;
    uint256 assetIndexBefore;
    uint256 discountPercent;
  }

  // Events to listen
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Mint(
    address indexed caller,
    address indexed onBehalfOf,
    uint256 value,
    uint256 balanceIncrease,
    uint256 index
  );
  event Burn(
    address indexed from,
    address indexed target,
    uint256 value,
    uint256 balanceIncrease,
    uint256 index
  );
  event DiscountPercentUpdated(
    address indexed user,
    uint256 oldDiscountPercent,
    uint256 indexed newDiscountPercent
  );
  event ATokenSet(address indexed);

  function borrowAction(address user, uint256 amount) public {
    borrowActionOnBehalf(user, user, amount);
  }

  function borrowActionOnBehalf(address caller, address onBehalfOf, uint256 amount) public {
    vm.stopPrank();

    BorrowState memory bs;
    bs.supplyBeforeAction = GHO_TOKEN.totalSupply();
    bs.debtSupplyBeforeAction = GHO_DEBT_TOKEN.totalSupply();
    bs.debtScaledSupplyBeforeAction = GHO_DEBT_TOKEN.scaledTotalSupply();
    bs.balanceBeforeAction = GHO_TOKEN.balanceOf(onBehalfOf);
    bs.debtScaledBalanceBeforeAction = GHO_DEBT_TOKEN.scaledBalanceOf(onBehalfOf);
    bs.debtBalanceBeforeAction = GHO_DEBT_TOKEN.balanceOf(onBehalfOf);
    bs.userIndexBeforeAction = GHO_DEBT_TOKEN.getPreviousIndex(onBehalfOf);
    bs.userInterestsBeforeAction = GHO_DEBT_TOKEN.getBalanceFromInterest(onBehalfOf);
    bs.assetIndexBefore = POOL.getReserveNormalizedVariableDebt(address(GHO_TOKEN));
    bs.discountPercent = GHO_DEBT_TOKEN.getDiscountPercent(onBehalfOf);

    if (bs.userIndexBeforeAction == 0) {
      bs.userIndexBeforeAction = 1e27;
    }

    (uint256 computedInterest, uint256 discountScaled, ) = DebtUtils.computeDebt(
      bs.userIndexBeforeAction,
      bs.assetIndexBefore,
      bs.debtScaledBalanceBeforeAction,
      bs.userInterestsBeforeAction,
      bs.discountPercent
    );
    uint256 newDiscountRate = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
      (bs.debtScaledBalanceBeforeAction - discountScaled).rayMul(bs.assetIndexBefore) + amount,
      IERC20(address(STK_TOKEN)).balanceOf(onBehalfOf)
    );

    if (newDiscountRate != bs.discountPercent) {
      vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
      emit DiscountPercentUpdated(onBehalfOf, bs.discountPercent, newDiscountRate);
    }

    vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
    emit Transfer(address(0), onBehalfOf, amount + computedInterest);
    vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
    emit Mint(caller, onBehalfOf, amount + computedInterest, computedInterest, bs.assetIndexBefore);

    // Action
    vm.prank(caller);
    POOL.borrow(address(GHO_TOKEN), amount, 2, 0, onBehalfOf);

    // Checks
    assertEq(
      GHO_TOKEN.balanceOf(onBehalfOf),
      bs.balanceBeforeAction + amount,
      'Gho amount doest not match borrow'
    );
    assertEq(GHO_DEBT_TOKEN.getDiscountPercent(onBehalfOf), newDiscountRate);
    assertEq(
      GHO_TOKEN.totalSupply(),
      bs.supplyBeforeAction + amount,
      'Gho total supply does not match borrow'
    );

    assertEq(
      GHO_DEBT_TOKEN.scaledBalanceOf(onBehalfOf),
      bs.debtScaledBalanceBeforeAction + amount.rayDiv(bs.assetIndexBefore) - discountScaled,
      'Gho debt token balance does not match borrow'
    );
    assertEq(
      GHO_DEBT_TOKEN.scaledTotalSupply(),
      bs.debtScaledSupplyBeforeAction + amount.rayDiv(bs.assetIndexBefore) - discountScaled,
      'Gho debt token Supply does not match borrow'
    );
    assertEq(
      GHO_DEBT_TOKEN.getBalanceFromInterest(onBehalfOf),
      bs.userInterestsBeforeAction + computedInterest,
      'Gho debt interests does not match borrow'
    );
  }

  function repayAction(address user, uint256 amount) public {
    vm.stopPrank();

    BorrowState memory bs;
    bs.supplyBeforeAction = GHO_TOKEN.totalSupply();
    bs.debtSupplyBeforeAction = GHO_DEBT_TOKEN.totalSupply();
    bs.debtScaledSupplyBeforeAction = GHO_DEBT_TOKEN.scaledTotalSupply();
    bs.balanceBeforeAction = GHO_TOKEN.balanceOf(user);
    bs.debtScaledBalanceBeforeAction = GHO_DEBT_TOKEN.scaledBalanceOf(user);
    bs.debtBalanceBeforeAction = GHO_DEBT_TOKEN.balanceOf(user);
    bs.userIndexBeforeAction = GHO_DEBT_TOKEN.getPreviousIndex(user);
    bs.userInterestsBeforeAction = GHO_DEBT_TOKEN.getBalanceFromInterest(user);
    bs.assetIndexBefore = POOL.getReserveNormalizedVariableDebt(address(GHO_TOKEN));
    bs.discountPercent = GHO_DEBT_TOKEN.getDiscountPercent(user);
    uint256 expectedDebt = 0;
    uint256 expectedBurnOffset = 0;

    if (bs.userIndexBeforeAction == 0) {
      bs.userIndexBeforeAction = 1e27;
    }

    (uint256 computedInterest, uint256 discountScaled, ) = DebtUtils.computeDebt(
      bs.userIndexBeforeAction,
      bs.assetIndexBefore,
      bs.debtScaledBalanceBeforeAction,
      bs.userInterestsBeforeAction,
      bs.discountPercent
    );
    uint256 newDiscountRate = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
      (bs.debtScaledBalanceBeforeAction - discountScaled).rayMul(bs.assetIndexBefore) - amount,
      IERC20(address(STK_TOKEN)).balanceOf(user)
    );

    if (amount <= (bs.userInterestsBeforeAction + computedInterest)) {
      expectedDebt = bs.userInterestsBeforeAction + computedInterest - amount;
    } else {
      expectedBurnOffset = amount - bs.userInterestsBeforeAction + computedInterest;
    }

    if (newDiscountRate != bs.discountPercent) {
      vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
      emit DiscountPercentUpdated(user, bs.discountPercent, newDiscountRate);
    }

    if (computedInterest > amount) {
      vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
      emit Transfer(address(0), user, computedInterest - amount);
    } else {
      vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
      emit Transfer(user, address(0), amount - computedInterest);
      //vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
      //emit Burn(user, user, amount - computedInterest, computedInterest, bs.assetIndexBefore);
    }

    // Action
    vm.startPrank(user);
    GHO_TOKEN.approve(address(POOL), amount);
    POOL.repay(address(GHO_TOKEN), amount, 2, user);
    vm.stopPrank();

    // Checks
    assertEq(
      GHO_TOKEN.balanceOf(user),
      bs.balanceBeforeAction - amount,
      'Gho amount doest not match repay'
    );
    assertEq(GHO_DEBT_TOKEN.getDiscountPercent(user), newDiscountRate);
    if (expectedBurnOffset != 0) {
      assertEq(
        GHO_TOKEN.totalSupply(),
        bs.supplyBeforeAction - amount + computedInterest + bs.userInterestsBeforeAction,
        'Gho total supply does not match repay b'
      );
    } else {
      assertEq(
        GHO_TOKEN.totalSupply(),
        bs.supplyBeforeAction,
        'Gho total supply does not match repay a'
      );
    }

    assertEq(
      GHO_DEBT_TOKEN.scaledBalanceOf(user),
      bs.debtScaledBalanceBeforeAction - amount.rayDiv(bs.assetIndexBefore) - discountScaled,
      'Gho debt token balance does not match repay'
    );
    assertEq(
      GHO_DEBT_TOKEN.scaledTotalSupply(),
      bs.debtScaledSupplyBeforeAction - amount.rayDiv(bs.assetIndexBefore) - discountScaled,
      'Gho debt token Supply does not match repay'
    );
    assertEq(
      GHO_DEBT_TOKEN.getBalanceFromInterest(user),
      expectedDebt,
      'Gho debt interests does not match repay'
    );
  }

  function mintAndStakeDiscountToken(address user, uint256 amount) public {
    vm.prank(faucet);
    AAVE_TOKEN.mint(user, amount);

    vm.startPrank(user);
    AAVE_TOKEN.approve(address(STK_TOKEN), amount);
    STK_TOKEN.stake(user, amount);
    vm.stopPrank();
  }

  function rebalanceDiscountAction(address user) public {
    vm.stopPrank();

    BorrowState memory bs;
    bs.supplyBeforeAction = GHO_TOKEN.totalSupply();
    bs.debtSupplyBeforeAction = GHO_DEBT_TOKEN.totalSupply();
    bs.debtScaledSupplyBeforeAction = GHO_DEBT_TOKEN.scaledTotalSupply();
    bs.balanceBeforeAction = GHO_TOKEN.balanceOf(user);
    bs.debtScaledBalanceBeforeAction = GHO_DEBT_TOKEN.scaledBalanceOf(user);
    bs.debtBalanceBeforeAction = GHO_DEBT_TOKEN.balanceOf(user);
    bs.userIndexBeforeAction = GHO_DEBT_TOKEN.getPreviousIndex(user);
    bs.userInterestsBeforeAction = GHO_DEBT_TOKEN.getBalanceFromInterest(user);
    bs.assetIndexBefore = POOL.getReserveNormalizedVariableDebt(address(GHO_TOKEN));
    bs.discountPercent = GHO_DEBT_TOKEN.getDiscountPercent(user);

    if (bs.userIndexBeforeAction == 0) {
      bs.userIndexBeforeAction = 1e27;
    }

    (uint256 computedInterest, uint256 discountScaled, ) = DebtUtils.computeDebt(
      bs.userIndexBeforeAction,
      bs.assetIndexBefore,
      bs.debtScaledBalanceBeforeAction,
      bs.userInterestsBeforeAction,
      bs.discountPercent
    );
    uint256 newDiscountRate = GHO_DISCOUNT_STRATEGY.calculateDiscountRate(
      (bs.debtScaledBalanceBeforeAction - discountScaled).rayMul(bs.assetIndexBefore),
      IERC20(address(STK_TOKEN)).balanceOf(user)
    );

    if (newDiscountRate != bs.discountPercent) {
      vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
      emit DiscountPercentUpdated(user, bs.discountPercent, newDiscountRate);
    }

    vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
    emit Transfer(address(0), user, computedInterest);
    vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
    emit Mint(address(0), user, computedInterest, computedInterest, bs.assetIndexBefore);

    // Action
    vm.prank(user);
    GHO_DEBT_TOKEN.rebalanceUserDiscountPercent(user);

    // Checks
    assertEq(
      GHO_TOKEN.balanceOf(user),
      bs.balanceBeforeAction,
      'Gho amount doest not match rebalance'
    );
    assertEq(GHO_DEBT_TOKEN.getDiscountPercent(user), newDiscountRate);
    assertEq(
      GHO_TOKEN.totalSupply(),
      bs.supplyBeforeAction,
      'Gho total supply does not match rebalance'
    );

    assertEq(
      GHO_DEBT_TOKEN.scaledBalanceOf(user),
      bs.debtScaledBalanceBeforeAction - discountScaled,
      'Gho debt token balance does not match rebalance'
    );
    assertEq(
      GHO_DEBT_TOKEN.scaledTotalSupply(),
      bs.debtScaledSupplyBeforeAction - discountScaled,
      'Gho debt token Supply does not match borrow'
    );
    assertEq(
      GHO_DEBT_TOKEN.getBalanceFromInterest(user),
      bs.userInterestsBeforeAction + computedInterest,
      'Gho debt interests does not match borrow'
    );
  }
}

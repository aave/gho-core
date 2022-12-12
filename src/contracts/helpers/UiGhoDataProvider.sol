// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {IUiGhoDataProvider} from './interfaces/IUiGhoDataProvider.sol';
import {GhoDiscountRateStrategy} from '../facilitators/aave/interestStrategy/GhoDiscountRateStrategy.sol';
import {IGhoDiscountRateStrategy} from '../facilitators/aave/tokens/interfaces/IGhoDiscountRateStrategy.sol';
import {IGhoVariableDebtToken} from '../facilitators/aave/tokens/interfaces/IGhoVariableDebtToken.sol';
import {IGhoToken} from '../gho/interfaces/IGhoToken.sol';

contract UiGhoDataProvider is IUiGhoDataProvider {
  IPool public immutable pool;
  address public immutable ghoToken;

  constructor(IPool _pool, address _ghoToken) {
    pool = _pool;
    ghoToken = _ghoToken;
  }

  function getGhoReserveData() public view override returns (GhoReserveData memory) {
    GhoReserveData memory ghoReserveData;

    DataTypes.ReserveData memory baseData = pool.getReserveData(ghoToken);
    address discountRateStrategyAddress = IGhoVariableDebtToken(baseData.variableDebtTokenAddress)
      .getDiscountRateStrategy();
    GhoDiscountRateStrategy discountRateStrategy = GhoDiscountRateStrategy(
      discountRateStrategyAddress
    );

    IGhoToken.Bucket memory aaveFacilitatorBucket = IGhoToken(ghoToken).getFacilitatorBucket(
      baseData.aTokenAddress
    );

    ghoReserveData.ghoBaseVariableBorrowRate = baseData.currentVariableBorrowRate;
    ghoReserveData.ghoReserveLastUpdateTimestamp = baseData.lastUpdateTimestamp;
    ghoReserveData.ghoCurrentBorrowIndex = baseData.variableBorrowIndex;
    ghoReserveData.ghoDiscountedPerToken = discountRateStrategy.GHO_DISCOUNTED_PER_DISCOUNT_TOKEN();
    ghoReserveData.ghoDiscountRate = discountRateStrategy.DISCOUNT_RATE();
    ghoReserveData.ghoMinDebtTokenBalanceForDiscount = discountRateStrategy
      .MIN_DISCOUNT_TOKEN_BALANCE();
    ghoReserveData.ghoMinDiscountTokenBalanceForDiscount = discountRateStrategy
      .MIN_DEBT_TOKEN_BALANCE();
    ghoReserveData.ghoDiscountLockPeriod = IGhoVariableDebtToken(baseData.variableDebtTokenAddress)
      .getDiscountLockPeriod();
    ghoReserveData.aaveFacilitatorBucketLevel = aaveFacilitatorBucket.level;
    ghoReserveData.aaveFacilitatorBucketMaxCapacity = aaveFacilitatorBucket.maxCapacity;

    return ghoReserveData;
  }

  function getGhoUserData(address user) public view override returns (GhoUserData memory) {
    GhoUserData memory ghoUserData;

    DataTypes.ReserveData memory baseData = pool.getReserveData(ghoToken);
    address discountToken = IGhoVariableDebtToken(baseData.variableDebtTokenAddress)
      .getDiscountToken();

    ghoUserData.userGhoDiscountRate = IGhoVariableDebtToken(baseData.variableDebtTokenAddress)
      .getDiscountPercent(user);
    ghoUserData.userDiscountTokenBalance = IERC20(discountToken).balanceOf(user);
    ghoUserData.userPreviousGhoBorrowIndex = IGhoVariableDebtToken(
      baseData.variableDebtTokenAddress
    ).getPreviousIndex(user);
    ghoUserData.userGhoScaledBorrowBalance = IGhoVariableDebtToken(
      baseData.variableDebtTokenAddress
    ).scaledBalanceOf(user);
    ghoUserData.userDiscountLockPeriodEndTimestamp = IGhoVariableDebtToken(
      baseData.variableDebtTokenAddress
    ).getUserRebalanceTimestamp(user);

    return ghoUserData;
  }
}

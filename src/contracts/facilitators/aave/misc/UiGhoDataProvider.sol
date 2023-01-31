// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {IGhoToken} from '../../../gho/interfaces/IGhoToken.sol';
import {GhoDiscountRateStrategy} from '../interestStrategy/GhoDiscountRateStrategy.sol';
import {IGhoVariableDebtToken} from '../tokens/interfaces/IGhoVariableDebtToken.sol';
import {IUiGhoDataProvider} from './interfaces/IUiGhoDataProvider.sol';

/**
 * @title UiGhoDataProvider
 * @author Aave
 * @notice Data provider of GHO token as a reserve within the Aave Protocol
 */
contract UiGhoDataProvider is IUiGhoDataProvider {
  IPool public immutable POOL;
  IGhoToken public immutable GHO;

  /**
   * @dev Constructor
   * @param pool The address of the Pool contract
   * @param ghoToken The address of the GhoToken contract
   */
  constructor(IPool pool, IGhoToken ghoToken) {
    POOL = pool;
    GHO = ghoToken;
  }

  /// @inheritdoc IUiGhoDataProvider
  function getGhoReserveData() public view override returns (GhoReserveData memory) {
    GhoReserveData memory ghoReserveData;

    DataTypes.ReserveData memory baseData = POOL.getReserveData(address(GHO));
    address discountRateStrategyAddress = IGhoVariableDebtToken(baseData.variableDebtTokenAddress)
      .getDiscountRateStrategy();
    GhoDiscountRateStrategy discountRateStrategy = GhoDiscountRateStrategy(
      discountRateStrategyAddress
    );

    (uint256 bucketCapacity, uint256 bucketLevel) = GHO.getFacilitatorBucket(
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
    ghoReserveData.aaveFacilitatorBucketLevel = bucketLevel;
    ghoReserveData.aaveFacilitatorBucketMaxCapacity = bucketCapacity;

    return ghoReserveData;
  }

  /// @inheritdoc IUiGhoDataProvider
  function getGhoUserData(address user) public view override returns (GhoUserData memory) {
    GhoUserData memory ghoUserData;

    DataTypes.ReserveData memory baseData = POOL.getReserveData(address(GHO));
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

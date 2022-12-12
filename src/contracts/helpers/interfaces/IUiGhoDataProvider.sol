// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

interface IUiGhoDataProvider {
  struct GhoReserveData {
    uint256 ghoBaseVariableBorrowRate;
    uint256 ghoDiscountedPerToken;
    uint256 ghoDiscountRate;
    uint256 ghoDiscountLockPeriod;
    uint256 ghoMinDebtTokenBalanceForDiscount;
    uint256 ghoMinDiscountTokenBalanceForDiscount;
    uint40 ghoReserveLastUpdateTimestamp;
    uint128 ghoCurrentBorrowIndex;
    uint128 aaveFacilitatorBucketLevel;
    uint128 aaveFacilitatorBucketMaxCapacity;
  }

  struct GhoUserData {
    uint256 userGhoDiscountRate;
    uint256 userDiscountTokenBalance;
    uint256 userPreviousGhoBorrowIndex;
    uint256 userGhoScaledBorrowBalance;
    uint256 userDiscountLockPeriodEndTimestamp;
  }

  function getGhoReserveData() external view returns (GhoReserveData memory);

  function getGhoUserData(address user) external view returns (GhoUserData memory);
}

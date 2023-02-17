// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title IUiGhoDataProvider
 * @author Aave
 * @notice Defines the basic interface of the UiGhoDataProvider
 */
interface IUiGhoDataProvider {
  struct GhoReserveData {
    uint256 ghoBaseVariableBorrowRate;
    uint256 ghoDiscountedPerToken;
    uint256 ghoDiscountRate;
    uint256 ghoMinDebtTokenBalanceForDiscount;
    uint256 ghoMinDiscountTokenBalanceForDiscount;
    uint40 ghoReserveLastUpdateTimestamp;
    uint128 ghoCurrentBorrowIndex;
    uint256 aaveFacilitatorBucketLevel;
    uint256 aaveFacilitatorBucketMaxCapacity;
  }

  struct GhoUserData {
    uint256 userGhoDiscountPercent;
    uint256 userDiscountTokenBalance;
    uint256 userPreviousGhoBorrowIndex;
    uint256 userGhoScaledBorrowBalance;
  }

  /**
   * @notice Returns data of the GHO reserve and the Aave Facilitator
   * @return An object with information related to the GHO reserve and the Aave Facilitator
   */
  function getGhoReserveData() external view returns (GhoReserveData memory);

  /**
   * @notice Returns data of the user's position on GHO
   * @return An object with information related to the user's position with regard to GHO
   */
  function getGhoUserData(address user) external view returns (GhoUserData memory);
}

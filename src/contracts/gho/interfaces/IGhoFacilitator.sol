// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

/**
 * @title IGhoFacilitator
 * @author Aave
 * @notice Defines the behavior of a Gho Facilitator
 */
interface IGhoFacilitator {
  /**
   * @dev Emitted when fees are distributed to the GhoTreasury
   * @param ghoTreasury The address of the ghoTreasury
   * @param asset The address of the asset transferred to the ghoTreasury
   * @param amount The amount of the asset transferred to the ghoTreasury
   */
  event FeesDistributedToTreasury(
    address indexed ghoTreasury,
    address indexed asset,
    uint256 amount
  );

  /**
   * @notice Distribute accumulated fees to the GhoTreasury
   */
  function distributeFeesToTreasury() external;
}

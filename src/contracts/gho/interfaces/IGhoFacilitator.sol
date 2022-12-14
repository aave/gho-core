// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

/**
 * @title IGhoFacilitator
 * @author Aave
 * @notice Defines the behavior of a GhoFacilitator
 */
interface IGhoFacilitator {
  /**
   * @dev Emitted fees are distributed to the GhoTreasury
   * @param ghoTreasury The address of the ghoTreasury
   * @param amount The amount of Gho transferred to the ghoTreasury
   */
  event FeesDistributedToTreasury(address indexed ghoTreasury, uint256 amount);

  /**
   * @notice Distribute accumulated fees to the GHO treasury
   */
  function distributeFeesToTreasury() external;
}

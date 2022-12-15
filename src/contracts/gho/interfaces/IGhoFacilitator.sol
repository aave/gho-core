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
   * @dev Emitted when Gho Treasury address is updated
   * @param oldGhoTreasury The address of the old GhoTreasury contract
   * @param newGhoTreasury The address of the new GhoTreasury contract
   */
  event GhoTreasuryUpdated(address indexed oldGhoTreasury, address indexed newGhoTreasury);

  /**
   * @notice Distribute fees to the GhoTreasury
   */
  function distributeFeesToTreasury() external;

  /**
   * @notice Updates the address of the Gho Treasury
   * @dev Extra precaution when updating this address. It is where revenue fees are sent to
   * @param newGhoTreasury The address of the GhoTreasury
   */
  function updateGhoTreasury(address newGhoTreasury) external;

  /**
   * @notice Returns the address of the Gho Treasury
   * @return The address of the GhoTreasury contract
   */
  function getGhoTreasury() external view returns (address);
}

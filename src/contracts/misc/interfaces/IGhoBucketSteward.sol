// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title IGhoBucketSteward
 * @author Aave Labs
 * @notice Defines the basic interface of the GhoBucketSteward
 */
interface IGhoBucketSteward {
  /**
   * @notice Updates the bucket capacity of facilitator, only if:
   * - respects `MINIMUM_DELAY`, the minimum time delay between updates
   * - the update changes up to 100% upwards
   * - the facilitator is controlled
   * @dev Only callable by Risk Council
   * @param facilitator The facilitator address
   * @param newBucketCapacity The new facilitator bucket capacity
   */
  function updateFacilitatorBucketCapacity(address facilitator, uint128 newBucketCapacity) external;

  /**
   * @notice Adds/Removes controlled facilitators
   * @dev Only callable by owner
   * @param facilitatorList A list of facilitators addresses to add to control
   * @param approve True to add as controlled facilitators, false to remove
   */
  function setControlledFacilitator(address[] memory facilitatorList, bool approve) external;

  /**
   * @notice Returns the list of controlled facilitators by this steward.
   * @return An array of facilitator addresses
   */
  function getControlledFacilitators() external view returns (address[] memory);

  /**
   * @notice Checks if a facilitator is controlled by this steward
   * @param facilitator The facilitator address to check
   * @return True if the facilitator is controlled by this steward
   */
  function isControlledFacilitator(address facilitator) external view returns (bool);

  /**
   * @notice Returns timestamp of the facilitators last bucket capacity update
   * @param facilitator The facilitator address
   * @return The unix time of the last bucket capacity (in seconds).
   */
  function getFacilitatorBucketCapacityTimelock(address facilitator) external view returns (uint40);

  /**
   * @notice Returns the minimum delay that must be respected between parameters update.
   * @return The minimum delay between parameter updates (in seconds)
   */
  function MINIMUM_DELAY() external view returns (uint256);

  /**
   * @notice Returns the address of the Gho Token
   * @return The address of the GhoToken
   */
  function GHO_TOKEN() external view returns (address);

  /**
   * @notice Returns the address of the risk council
   * @return The address of the RiskCouncil
   */
  function RISK_COUNCIL() external view returns (address);
}

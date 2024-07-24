// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title IGhoCcipSteward
 * @author Aave Labs
 * @notice Defines the basic interface of the GhoCcipSteward
 */
interface IGhoCcipSteward {
  /**
   * @notice Adds/Removes controlled facilitators
   * @dev Only callable by owner
   * @param facilitatorList A list of facilitators addresses to add to control
   * @param approve True to add as controlled facilitators, false to remove
   */
  function setControlledFacilitator(address[] memory facilitatorList, bool approve) external;

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

  /**
   * @notice Returns the list of controlled facilitators by this steward.
   * @return An array of facilitator addresses
   */
  function getControlledFacilitators() external view returns (address[] memory);

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
   * @notice Updates the CCIP bridge limit
   * @dev Only callable by Risk Council
   * @param newBridgeLimit The new desired bridge limit
   */
  function updateBridgeLimit(uint256 newBridgeLimit) external;

  /**
   * @notice Updates the CCIP rate limit config
   * @dev Only callable by Risk Council
   * @param remoteChainSelector The remote chain selector for which the rate limits apply.
   * @param outboundEnabled True if the outbound rate limiter is enabled.
   * @param outboundCapacity The outbound rate limiter capacity.
   * @param outboundRate The outbound rate limiter rate.
   * @param inboundEnabled True if the inbound rate limiter is enabled.
   * @param inboundCapacity The inbound rate limiter capacity.
   * @param inboundRate The inbound rate limiter rate.
   */
  function updateRateLimit(
    uint64 remoteChainSelector,
    bool outboundEnabled,
    uint128 outboundCapacity,
    uint128 outboundRate,
    bool inboundEnabled,
    uint128 inboundCapacity,
    uint128 inboundRate
  ) external;

  /**
   * @notice Returns the minimum delay that must be respected between parameters update.
   * @return The minimum delay between parameter updates (in seconds)
   */
  function MINIMUM_DELAY() external view returns (uint256);

  /**
   * @notice Returns the address of the Gho CCIP Token Pool
   * @return The address of the Gho CCIP Token Pool
   */
  function GHO_TOKEN_POOL() external view returns (address);

  /**
   * @notice Returns timestamp of the facilitators last bucket capacity update
   * @param facilitator The facilitator address
   * @return The unix time of the last bucket capacity (in seconds).
   */
  function getFacilitatorBucketCapacityTimelock(address facilitator) external view returns (uint40);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title IGhoCcipSteward
 * @author Aave Labs
 * @notice Defines the basic interface of the GhoCcipSteward
 */
interface IGhoCcipSteward {
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
   * @notice returns whether the bridge limit is enabled
   * @dev For use on Ethereum, not remote networks
   */
  function BRIDGE_LIMIT_ENABLED() external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {RateLimiter} from '../deps/Dependencies.sol';

/**
 * @title IGhoStewardV2
 * @author Aave Labs
 * @notice Defines the basic interface of the GhoStewardV2
 */
interface IArbGhoSteward {
  struct GhoDebounce {
    uint40 ghoBorrowCapLastUpdate;
    uint40 ghoBorrowRateLastUpdate;
  }

  struct GsmDebounce {
    uint40 gsmExposureCapLastUpdated;
    uint40 gsmFeeStrategyLastUpdated;
  }

  /**
   * @notice Updates the CCIP rate limit config
   * @dev Only callable by Risk Council
   * @param remoteChainSelector The remote chain selector for which the rate limits apply.
   * @param outboundConfig The new outbound rate limiter config.
   * @param inboundConfig The new inbound rate limiter config.
   */
  function updateRateLimit(
    uint64 remoteChainSelector,
    RateLimiter.Config calldata outboundConfig,
    RateLimiter.Config calldata inboundConfig
  ) external;

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
   * @notice Updates the borrow rate of GHO, only if:
   * - respects `MINIMUM_DELAY`, the minimum time delay between updates
   * - the update changes up to `GHO_BORROW_RATE_CHANGE_MAX` upwards or downwards
   * - the update is lower than `GHO_BORROW_RATE_MAX`
   * @dev Only callable by Risk Council
   * @param newBorrowRate The new variable borrow rate (expressed in ray) (e.g. 0.0150e27 results in 1.50%)
   */
  function updateGhoBorrowRate(uint256 newBorrowRate) external;

  /**
   * @notice Adds/Removes controlled facilitators
   * @dev Only callable by owner
   * @param facilitatorList A list of facilitators addresses to add to control
   * @param approve True to add as controlled facilitators, false to remove
   */
  function setControlledFacilitator(address[] memory facilitatorList, bool approve) external;

  /**
   * @notice Returns the maximum increase/decrease for GHO borrow rate updates.
   * @return The maximum increase change for borrow rate updates in ray (e.g. 0.010e27 results in 1.00%)
   */
  function GHO_BORROW_RATE_CHANGE_MAX() external view returns (uint256);

  /**
   * @notice Returns maximum value that can be assigned to GHO borrow rate.
   * @return The maximum value that can be assigned to GHO borrow rate in ray (e.g. 0.01e27 results in 1.0%)
   */
  function GHO_BORROW_RATE_MAX() external view returns (uint256);

  /**
   * @notice Returns the minimum delay that must be respected between parameters update.
   * @return The minimum delay between parameter updates (in seconds)
   */
  function MINIMUM_DELAY() external view returns (uint256);

  /**
   * @notice Returns the address of the Pool Addresses Provider of the Aave V3 Ethereum Pool
   * @return The address of the PoolAddressesProvider of Aave V3 Ethereum Pool
   */
  function POOL_ADDRESSES_PROVIDER() external view returns (address);

  /**
   * @notice Returns the address of the Gho Token
   * @return The address of the GhoToken
   */
  function GHO_TOKEN() external view returns (address);

  /**
   * @notice Returns the address of the Gho CCIP Token Pool
   * @return The address of the Gho CCIP Token Pool
   */
  function GHO_TOKEN_POOL() external view returns (address);

  /**
   * @notice Returns the address of the fixed rate strategy factory
   * @return The address of the FixedRateStrategyFactory
   */
  function FIXED_RATE_STRATEGY_FACTORY() external view returns (address);

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
   * @notice Returns timestamp of the last update of GHO parameters
   * @return The GhoDebounce struct describing the last update of GHO parameters
   */
  function getGhoTimelocks() external view returns (GhoDebounce memory);

  /**
   * @notice Returns timestamp of the facilitators last bucket capacity update
   * @param facilitator The facilitator address
   * @return The unix time of the last bucket capacity (in seconds).
   */
  function getFacilitatorBucketCapacityTimelock(address facilitator) external view returns (uint40);
}
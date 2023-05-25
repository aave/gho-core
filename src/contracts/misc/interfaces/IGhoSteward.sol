// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title IGhoSteward
 * @author Aave
 * @notice Defines the basic interface of the GhoSteward
 */
interface IGhoSteward {
  struct Debounce {
    uint40 borrowRateLastUpdated;
    uint40 bucketCapacityLastUpdated;
  }

  /**
   * @dev Emitted when the steward expiration is updated
   * @param oldStewardExpiration The old expiration unix time of the steward (in seconds)
   * @param oldStewardExpiration The new expiration unix time of the steward (in seconds)
   */
  event StewardExpirationUpdated(uint40 oldStewardExpiration, uint40 newStewardExpiration);

  /**
   * @notice Returns the address of the Aave Short Executor
   * @return The address of the Aave ShortExecutor
   */
  function AAVE_SHORT_EXECUTOR() external view returns (address);

  /**
   * @notice Returns the minimum delay that must be respected between updating a specific parameter twice
   * @return The minimum delay between parameter updates (in seconds)
   */
  function MINIMUM_DELAY() external view returns (uint256);

  /**
   * @notice Returns the maximum percentage change for borrow rate updates. The new borrow rate can only differ up to this percentage.
   * @return The maximum percentage change for borrow rate updates (e.g. 0.0050e4 is 50, which results in 0.5%)
   */
  function BORROW_RATE_CHANGE_MAX() external view returns (uint256);

  /**
   * @notice Returns the lifespan of the steward
   * @return The lifespan of the steward (in seconds)
   */
  function STEWARD_LIFESPAN() external view returns (uint40);

  /**
   * @notice Returns the address of the Pool Addresses Provider of the Aave V3 Ethereum Facilitator
   * @return The address of the PoolAddressesProvider of Aave V3 Ethereum Facilitator
   */
  function POOL_ADDRESSES_PROVIDER() external view returns (address);

  /**
   * @notice Returns the address of the Gho Token
   * @return The address of the GhoToken
   */
  function GHO_TOKEN() external view returns (address);

  /**
   * @notice Returns the address of the Risk Council
   * @return The address of the RiskCouncil
   */
  function RISK_COUNCIL() external view returns (address);

  /**
   * @notice Updates the borrow rate of GHO, only if:
   * - respects the debounce duration (5 day pause between updates must be respected)
   * - the update changes up to 0.50% upwards or downwards
   * @dev Only callable by Risk Council
   * @param newBorrowRate The new variable borrow rate (expressed in ray)
   */
  function updateBorrowRate(uint256 newBorrowRate) external;

  /**
   * @notice Updates the Bucket Capacity of the Aave V3 Ethereum Pool Facilitator, only if:
   * - respects the debounce duration (5 day pause between updates must be respected)
   * - the update changes up to 100% upwards
   * @dev Only callable by Risk Council
   * @param newBucketCapacity The new bucket capacity of the facilitator
   */
  function updateBucketCapacity(uint128 newBucketCapacity) external;

  /**
   * @notice Extends the steward expiration date by `STEWARD_LIFESPAN`
   * @dev Only callable by Aave Short Executor
   */
  function extendStewardExpiration() external;

  /**
   * @notice Returns the timelock values for all parameters updates
   * @return The Debounce struct with parameters' timelock
   */
  function getTimelock() external view returns (Debounce memory);

  /**
   * @notice Returns the expiration time of the steward
   * @return The expiration unix time of the steward (in seconds)
   */
  function getStewardExpiration() external view returns (uint40);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title IGhoStewardV2
 * @author Aave Labs
 * @notice Defines the basic interface of the GhoStewardV2
 */
interface IGhoStewardV2 {
  struct GsmDebounce {
    uint40 gsmExposureCapLastUpdated;
    uint40 gsmFeeStrategyLastUpdated;
  }

  /**
   * @notice Returns the maximum increase for GHO borrow rate updates.
   * @return The maximum increase change for borrow rate updates in ray (e.g. 0.01e27 results in 1.0%)
   */
  function GHO_BORROW_RATE_CHANGE_MAX() external view returns (uint256);

  /**
   * @notice Returns the maximum increase for GSM fee rates (buy or sell).
   * @return The maximum increase change for GSM fee rates updates in bps (e.g. 0.01e4 results in 1.0%)
   */
  function GSM_FEE_RATE_CHANGE_MAX() external view returns (uint256);

  /**
   * @notice Returns maximun value that can be assigned to GHO borrow rate.
   * @return The maximun value that can be assigned to GHO borrow rate in ray (e.g. 0.01e27 results in 1.0%)
   */
  function GHO_BORROW_RATE_MAX() external view returns (uint256);

  /**
   * @notice Returns the minimum delay that must be respected between parameters update.
   * @return The minimum delay between parameter updates (in seconds)
   */
  function MINIMUM_DELAY() external view returns (uint256);

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
   * @notice Returns the address of the risk council
   * @return The address of the RiskCouncil
   */
  function RISK_COUNCIL() external view returns (address);

  /**
   * @notice Updates the bucket capacity of facilitator, only if:
   * - respects the debounce duration (7 day pause between updates must be respected)
   * - the update changes up to 100% upwards
   * - the facilitator is controlled
   * @dev Only callable by Risk Council
   * @param facilitator The facilitator address
   * @param newBucketCapacity The new facilitator bucket capacity
   */
  function updateFacilitatorBucketCapacity(address facilitator, uint128 newBucketCapacity) external;

  /**
   * @notice Updates the borrow rate of GHO, only if:
   * - respects the debounce duration (7 day pause between updates must be respected)
   * - the update changes up to 0.5% upwards
   * - the update is lower than 9.5%
   * @dev Only callable by Risk Council
   * @param newBorrowRate The new variable borrow rate (expressed in ray) (e.g. 0.0150e27 results in 1.50%)
   */
  function updateGhoBorrowRate(uint256 newBorrowRate) external;

  /**
   * @notice Updates the borrow rate of GHO, only if:
   * - respects the debounce duration (7 day pause between updates must be respected)
   * - the GSM address is approved
   * - the update changes up to 100% upwards
   * @dev Only callable by Risk Council
   * @param gsm The gsm address to update
   * @param newExposureCap The new exposure cap
   */
  function updateGsmExposureCap(address gsm, uint128 newExposureCap) external;

  /**
   * @notice Updates the borrow rate of GHO, only if:
   * - respects the debounce duration (7 day pause between updates must be respected)
   * - the GSM address is approved
   * - the update changes up to 50 bps (0.5%) upwards (for both buy and sell individually);
   * @dev Only callable by Risk Council
   * @param gsm The gsm address to update
   * @param buyFee The new buy fee (expressed in bps) (e.g. 0.0150e4 results in 1.50%)
   * @param sellFee The new sell fee (expressed in bps) (e.g. 0.0150e4 results in 1.50%)
   */
  function updateGsmFeeStrategy(address gsm, uint256 buyFee, uint256 sellFee) external;

  /**
   * @notice Adds/Removes controlled facilitators
   * @dev Only callable by owner
   * @param facilitatorList A list of facilitators addresses to add to control
   * @param approve A boolean to control or remove control towards the facilitators
   */
  function controlFacilitators(address[] memory facilitatorList, bool approve) external;

  /**
   * @notice Returns the list of controlled facilitators.
   * @return An array of GSM addresses
   */
  function getControlledFacilitators() external view returns (address[] memory);

  /**
   * @notice Returns the GHO timelock value for borrow rate updates
   * @return The time of the last GHO borrow rate update (in seconds).
   */
  function getGhoBorrowRateTimelock() external view returns (uint40);

  /**
   * @notice Returns the Gsm timelocks values for all parameters updates
   * @param gsm The GSM address
   * @return The GsmDebounce struct with parameters' timelock
   */

  function getGsmTimelocks(address gsm) external view returns (GsmDebounce memory);

  /**
   * @notice Returns the facilitator timelock value for bucket capacity updates
   * @param facilitator The facilitator address
   * @return The time of the last bucket capacity (in seconds).
   */
  function getFacilitatorBucketCapacityTimelock(address facilitator) external view returns (uint40);

  /**
   * @notice Returns the list of Fixed Fee Strategies for GSM
   * @return An array of FixedFeeStrategy addresses
   */
  function getGsmFeeStrategies() external view returns (address[] memory);

  /**
   * @notice Returns the list of Interest Rate Strategies for GHO
   * @return An array of GhoInterestRateStrategy addresses
   */
  function getGhoBorrowRateStrategies() external view returns (address[] memory);
}

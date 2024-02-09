// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IGsm} from '../../facilitators/gsm/interfaces/IGsm.sol';

/**
 * @title IGhoStewardV2
 * @author Aave
 * @notice Defines the basic interface of the GhoStewardV2
 */
interface IGhoStewardV2 {
  struct Debounce {
    uint40 ghoBorrowRateLastUpdated;
  }

  /**
   * @notice Returns maximum value that can be assigned to GHO borrow cap
   * @return The maximum value that can be assigned to GHO borrow cap (18 decimals)
   */
  function GHO_BORROW_CAP_MAX() external view returns (uint256);

  /**
   * @notice Returns the maximum percentage change for borrow rate updates. The new borrow rate can only differ up to this percentage.
   * @return The maximum percentage change for borrow rate updates (e.g. 0.01e4 is 100, which results in 1.0%)
   */
  function GHO_BORROW_RATE_CHANGE_MAX() external view returns (uint256);

  /**
   * @notice Returns maximun value that can be assigned to GHO borrow rate.
   * @return The maximun value that can be assigned to GHO borrow rate (in bps, 9.5%)
   */
  function GHO_BORROW_RATE_MAX() external view returns (uint256);

  /**
   * @notice Returns the minimum delay that must be respected between updating a GHO borrow rate.
   * @return The minimum delay between GHO borrow rate updates (in seconds)
   */
  function GHO_BORROW_RATE_CHANGE_DELAY() external view returns (uint256);

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
   * @notice Returns the address of the Service provider
   * @return The address of the ServiceProvider
   */
  function SERVICE_PROVIDER() external view returns (address);

  function updateGhoBorrowCap(uint256 newBorrowCap) external;

  /**
   * @notice Updates the borrow rate of GHO, only if:
   * - respects the debounce duration (7 day pause between updates must be respected)
   * - the update changes up to 1.00% upwards or downwards
   * @dev Only callable by Risk Council
   * @param newBorrowRate The new variable borrow rate (expressed in ray) (e.g. 0.0150e27 results in 1.50%)
   */
  function updateGhoBorrowRate(uint256 newBorrowRate) external;

  function updateGsmExposureCap(IGsm gsm, uint128 newExposureCap) external;

  function updateGsmBucketCapacity(address gsm, uint128 newBucketCapacity) external;

  function updateGsmFeeStrategy(IGsm gsm, uint256 buyFee, uint256 sellFee) external;
}

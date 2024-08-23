// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title IGhoAaveSteward
 * @author Aave Labs
 * @notice Defines the basic interface of the GhoAaveSteward
 */
interface IGhoAaveSteward {
  /**
   * @notice Struct storing the last update by the steward of each borrow rate param
   */
  struct GhoDebounce {
    uint40 ghoBorrowCapLastUpdate;
    uint40 ghoSupplyCapLastUpdate;
    uint40 ghoBorrowRateLastUpdate;
  }

  /**
   * @notice Struct storing the configuration for the borrow rate params
   */
  struct BorrowRateConfig {
    uint16 optimalUsageRatioMaxChange;
    uint32 baseVariableBorrowRateMaxChange;
    uint32 variableRateSlope1MaxChange;
    uint32 variableRateSlope2MaxChange;
  }

  /**
   * @notice Updates the borrow rate of GHO, only if:
   * - respects `MINIMUM_DELAY`, the minimum time delay between updates
   * - the update changes parameters up to the maximum allowed change according to risk config
   * - the update is lower than `GHO_BORROW_RATE_MAX`
   * @dev Only callable by Risk Council
   * @dev Values are all expressed in BPS
   * @param optimalUsageRatio The new optimal usage ratio
   * @param baseVariableBorrowRate The new base variable borrow rate
   * @param variableRateSlope1 The new variable rate slope 1
   * @param variableRateSlope2 The new variable rate slope 2
   */
  function updateGhoBorrowRate(
    uint16 optimalUsageRatio,
    uint32 baseVariableBorrowRate,
    uint32 variableRateSlope1,
    uint32 variableRateSlope2
  ) external;

  /**
   * @notice Updates the GHO borrow cap, only if:
   * - respects `MINIMUM_DELAY`, the minimum time delay between updates
   * - the update changes up to 100% upwards or downwards
   * @dev Only callable by Risk Council
   * @param newBorrowCap The new borrow cap (in whole tokens)
   */
  function updateGhoBorrowCap(uint256 newBorrowCap) external;

  /**
   * @notice Updates the GHO supply cap, only if:
   * - respects `MINIMUM_DELAY`, the minimum time delay between updates
   * - the update changes up to 100% upwards or downwards
   * @dev Only callable by Risk Council
   * @param newSupplyCap The new supply cap (in whole tokens)
   */
  function updateGhoSupplyCap(uint256 newSupplyCap) external;

  /**
   * @notice Updates the configuration conditions for borrow rate changes
   * @dev Values are all expressed in BPS
   * @param optimalUsageRatioMaxChange The new allowed max percentage change for optimal usage ratio
   * @param baseVariableBorrowRateMaxChange The new allowed max percentage change for base variable borrow rate
   * @param variableRateSlope1MaxChange The new allowed max percentage change for variable rate slope 1
   * @param variableRateSlope2MaxChange The new allowed max percentage change for variable rate slope 2
   */
  function setBorrowRateConfig(
    uint16 optimalUsageRatioMaxChange,
    uint32 baseVariableBorrowRateMaxChange,
    uint32 variableRateSlope1MaxChange,
    uint32 variableRateSlope2MaxChange
  ) external;

  /**
   * @notice Returns the configuration conditions for a GHO borrow rate change
   * @return struct containing the borrow rate configuration
   */
  function getBorrowRateConfig() external view returns (BorrowRateConfig memory);

  /**
   * @notice Returns timestamp of the last update of GHO parameters
   * @return The GhoDebounce struct describing the last update of GHO parameters
   */
  function getGhoTimelocks() external view returns (GhoDebounce memory);

  /**
   * @notice Returns maximum value that can be assigned to GHO borrow rate.
   * @return The maximum value that can be assigned to GHO borrow rate in ray (e.g. 0.01e27 results in 1.0%)
   */
  function GHO_BORROW_RATE_MAX() external view returns (uint32);

  /**
   * @notice The address of pool data provider of the POOL the steward controls
   */
  function POOL_DATA_PROVIDER() external view returns (address);

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
   * @notice Returns the address of the risk council
   * @return The address of the RiskCouncil
   */
  function RISK_COUNCIL() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title IGhoAaveSteward
 * @author Aave Labs
 * @notice Defines the basic interface of the GhoAaveSteward
 */
interface IGhoAaveSteward {
  /**
   * @notice Emitted when the risk configuration for the risk params has been set
   * @param riskConfig struct containing the risk configurations
   */
  event RiskConfigSet(Config indexed riskConfig);

  /**
   * @notice Struct storing the last update by the steward of each risk param
   */
  struct GhoDebounce {
    uint40 ghoBorrowCapLastUpdate;
    uint40 ghoSupplyCapLastUpdate;
    uint40 ghoBorrowRateLastUpdate;
    uint40 riskConfigLastUpdate;
  }

  /**
   * @notice Struct storing the minimum delay and maximum percent change for a risk param
   */
  struct RiskParamConfig {
    uint40 minDelay;
    uint256 maxPercentChange;
  }

  /**
   * @notice Struct storing the risk configuration for all the risk param
   */
  struct Config {
    RiskParamConfig optimalUsageRatio;
    RiskParamConfig baseVariableBorrowRate;
    RiskParamConfig variableRateSlope1;
    RiskParamConfig variableRateSlope2;
  }

  /**
   * @notice Updates the borrow rate of GHO, only if:
   * - respects `MINIMUM_DELAY`, the minimum time delay between updates
   * - the update changes up to `GHO_BORROW_RATE_CHANGE_MAX` upwards or downwards
   * - the update is lower than `GHO_BORROW_RATE_MAX`
   * @dev Only callable by Risk Council
   * @param optimalUsageRatio The new optimal usage ratio
   * @param baseVariableBorrowRate The new base variable borrow rate
   * @param variableRateSlope1 The new variable rate slope 1
   * @param variableRateSlope2 The new variable rate slope 2
   */
  function updateGhoBorrowRate(
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
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
   * @notice method called by the Risk Council to set the risk configuration for the risk params
   * @param riskConfig struct containing the risk configurations
   */
  function setRiskConfig(Config calldata riskConfig) external;

  /**
   * @notice method to get the risk configuration set for all the risk params
   * @return struct containing the risk configurations
   */
  function getRiskConfig() external view returns (Config memory);

  /**
   * @notice Returns timestamp of the last update of GHO parameters
   * @return The GhoDebounce struct describing the last update of GHO parameters
   */
  function getGhoTimelocks() external view returns (GhoDebounce memory);

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
   * @notice The address of the config engine used to perform the borrow rate update via delegatecall
   */
  function CONFIG_ENGINE() external view returns (address);

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

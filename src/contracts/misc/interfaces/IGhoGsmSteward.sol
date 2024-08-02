// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/**
 * @title IGhoGsmSteward
 * @author Aave Labs
 * @notice Defines the basic interface of the GhoGsmSteward
 */
interface IGhoGsmSteward {
  struct GsmDebounce {
    uint40 gsmExposureCapLastUpdated;
    uint40 gsmFeeStrategyLastUpdated;
  }

  /**
   * @notice Returns the minimum delay that must be respected between parameters update.
   * @return The minimum delay between parameter updates (in seconds)
   */
  function MINIMUM_DELAY() external view returns (uint256);

  /**
   * @notice Returns the address of the GSM Fee Strategy Factory
   * @return The address of the GSM Fee Strategy Factory
   */
  function GSM_FEE_STRATEGY_FACTORY() external view returns (address);

  /**
   * @notice Returns the address of the risk council
   * @return The address of the RiskCouncil
   */
  function RISK_COUNCIL() external view returns (address);

  /**
   * @notice Updates the exposure cap of the GSM, only if:
   * - respects `MINIMUM_DELAY`, the minimum time delay between updates
   * - the update changes up to 100% upwards or downwards
   * @dev Only callable by Risk Council
   * @param gsm The gsm address to update
   * @param newExposureCap The new exposure cap (in underlying asset terms)
   */
  function updateGsmExposureCap(address gsm, uint128 newExposureCap) external;

  /**
   * @notice Updates the fixed percent fees of the GSM, only if:
   * - respects `MINIMUM_DELAY`, the minimum time delay between updates
   * - the update changes up to `GSM_FEE_RATE_CHANGE_MAX` upwards or downwards (for both buy and sell individually)
   * @dev Only callable by Risk Council
   * @param gsm The gsm address to update
   * @param buyFee The new buy fee (expressed in bps) (e.g. 0.0150e4 results in 1.50%)
   * @param sellFee The new sell fee (expressed in bps) (e.g. 0.0150e4 results in 1.50%)
   */
  function updateGsmBuySellFees(address gsm, uint256 buyFee, uint256 sellFee) external;

  /**
   * @notice Returns the maximum increase for GSM fee rates (buy or sell).
   * @return The maximum increase change for GSM fee rates updates in bps (e.g. 0.010e4 results in 1.00%)
   */
  function GSM_FEE_RATE_CHANGE_MAX() external view returns (uint256);

  /**
   * @notice Returns timestamp of the last update of Gsm parameters
   * @param gsm The GSM address
   * @return The GsmDebounce struct describing the last update of GSM parameters
   */
  function getGsmTimelocks(address gsm) external view returns (GsmDebounce memory);

  /**
   * @notice Returns the list of Fixed Fee Strategies for GSM
   * @return An array of FixedFeeStrategy addresses
   */
  function getGsmFeeStrategies() external view returns (address[] memory);
}

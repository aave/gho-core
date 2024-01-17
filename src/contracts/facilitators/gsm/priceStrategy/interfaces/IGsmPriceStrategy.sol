// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IGsmPriceStrategy
 * @author Aave
 * @notice Defines the behaviour of Price Strategies
 */
interface IGsmPriceStrategy {
  /**
   * @notice Returns the number of decimals of GHO
   * @return The number of decimals of GHO
   */
  function GHO_DECIMALS() external view returns (uint256);

  /**
   * @notice Returns the address of the underlying asset being priced
   * @return The address of the underlying asset
   */
  function UNDERLYING_ASSET() external view returns (address);

  /**
   * @notice Returns the decimals of the underlying asset being priced
   * @return The number of decimals of the underlying asset
   */
  function UNDERLYING_ASSET_DECIMALS() external view returns (uint256);

  /**
   * @notice Returns the price of the underlying asset (GHO denominated)
   * @param assetAmount The amount of the underlying asset to calculate the price of
   * @param roundUp True if the price should be rounded up, false if rounded down
   * @return The price of the underlying asset (expressed in GHO units)
   */
  function getAssetPriceInGho(uint256 assetAmount, bool roundUp) external view returns (uint256);

  /**
   * @notice Returns the price of GHO (denominated in the underlying asset)
   * @param ghoAmount The amount of GHO to calculate the price of
   * @param roundUp True if the price should be rounded up, false if rounded down
   * @return The price of the GHO amount (expressed in underlying asset units)
   */
  function getGhoPriceInAsset(uint256 ghoAmount, bool roundUp) external view returns (uint256);
}

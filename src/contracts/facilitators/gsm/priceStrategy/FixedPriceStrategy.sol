// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGsmPriceStrategy} from './interfaces/IGsmPriceStrategy.sol';

/**
 * @title FixedPriceStrategy
 * @author Aave
 * @notice Price strategy involving a fixed-rate conversion from an underlying asset to GHO
 */
contract FixedPriceStrategy is IGsmPriceStrategy {
  /// @inheritdoc IGsmPriceStrategy
  uint256 public constant GHO_DECIMALS = 18;

  /// @inheritdoc IGsmPriceStrategy
  uint256 public immutable PRICE_RATIO;

  /// @inheritdoc IGsmPriceStrategy
  address public immutable UNDERLYING_ASSET;

  /// @inheritdoc IGsmPriceStrategy
  uint256 public immutable UNDERLYING_ASSET_DECIMALS;

  uint256 internal immutable _underlyingAssetUnits;

  /**
   * @dev Constructor
   * @param priceRatio The price ratio from underlying asset to GHO (expressed in WAD)
   * @param underlyingAsset The address of the underlying asset
   * @param underlyingAssetDecimals The number of decimals of the underlying asset
   */
  constructor(uint256 priceRatio, address underlyingAsset, uint8 underlyingAssetDecimals) {
    PRICE_RATIO = priceRatio;
    UNDERLYING_ASSET = underlyingAsset;
    UNDERLYING_ASSET_DECIMALS = underlyingAssetDecimals;
    _underlyingAssetUnits = 10 ** underlyingAssetDecimals;
  }

  /// @inheritdoc IGsmPriceStrategy
  function getAssetPriceInGho(uint256 assetAmount) external view returns (uint256) {
    return (assetAmount * PRICE_RATIO) / _underlyingAssetUnits;
  }

  /// @inheritdoc IGsmPriceStrategy
  function getGhoPriceInAsset(uint256 ghoAmount) external view returns (uint256) {
    return PRICE_RATIO > 0 ? (ghoAmount * _underlyingAssetUnits) / PRICE_RATIO : 0;
  }
}

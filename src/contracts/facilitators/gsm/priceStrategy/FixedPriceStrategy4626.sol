// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';
import {IGsmPriceStrategy} from './interfaces/IGsmPriceStrategy.sol';

/**
 * @title FixedPriceStrategy4626
 * @author Aave
 * @notice Price strategy involving a fixed-rate conversion from an ERC4626 asset to GHO
 */
contract FixedPriceStrategy4626 is IGsmPriceStrategy {
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
    // conversion from 4626 shares to 4626 assets (rounding down)
    uint256 vaultAssets = IERC4626(UNDERLYING_ASSET).previewRedeem(assetAmount);
    return (vaultAssets * PRICE_RATIO) / _underlyingAssetUnits;
  }

  /// @inheritdoc IGsmPriceStrategy
  function getGhoPriceInAsset(uint256 ghoAmount) external view returns (uint256) {
    if (PRICE_RATIO == 0) return 0;
    uint256 vaultAssets = (ghoAmount * _underlyingAssetUnits) / PRICE_RATIO;
    // conversion from 4626 assets to 4626 shares (rounding down)
    return IERC4626(UNDERLYING_ASSET).previewDeposit(vaultAssets);
  }
}

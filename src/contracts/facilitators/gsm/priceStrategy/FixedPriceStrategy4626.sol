// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';
import {IGsmPriceStrategy} from './interfaces/IGsmPriceStrategy.sol';

/**
 * @title FixedPriceStrategy4626
 * @author Aave
 * @notice Price strategy involving a fixed-rate conversion from an ERC4626 vault to GHO
 * @dev 4626 vault assets represent the underlying asset held by a vault, vault shares are the vault token
 */
contract FixedPriceStrategy4626 is IGsmPriceStrategy {
  using Math for uint256;

  /// @inheritdoc IGsmPriceStrategy
  uint256 public constant GHO_DECIMALS = 18;

  /// @inheritdoc IGsmPriceStrategy
  address public immutable UNDERLYING_ASSET;

  /// @dev Underlying asset decimals represent decimals for the 4626 vault asset, not for the vault share
  uint256 public immutable UNDERLYING_ASSET_DECIMALS;

  /// @dev The price ratio from 4626 vault asset to GHO (expressed in WAD), e.g. a ratio of 2e18 means 2 GHO per 1 vault asset
  uint256 public immutable PRICE_RATIO;

  /// @dev Underlying asset units represent units for the 4626 vault asset, not for the vault share
  uint256 internal immutable _underlyingAssetUnits;

  /**
   * @dev Constructor
   * @param priceRatio The price ratio from 4626 vault asset to GHO (expressed in WAD)
   * @param underlyingAsset The address of the 4626 vault (i.e., corresponding to vault shares)
   * @param underlyingAssetDecimals The number of decimals of the 4626 vault asset
   */
  constructor(uint256 priceRatio, address underlyingAsset, uint8 underlyingAssetDecimals) {
    require(priceRatio > 0, 'INVALID_PRICE_RATIO');
    PRICE_RATIO = priceRatio;
    UNDERLYING_ASSET = underlyingAsset;
    UNDERLYING_ASSET_DECIMALS = underlyingAssetDecimals;
    _underlyingAssetUnits = 10 ** underlyingAssetDecimals;
  }

  /// @inheritdoc IGsmPriceStrategy
  function getAssetPriceInGho(uint256 assetAmount, bool roundUp) external view returns (uint256) {
    // conversion from 4626 shares to 4626 assets
    uint256 vaultAssets = roundUp
      ? IERC4626(UNDERLYING_ASSET).previewMint(assetAmount) // round up
      : IERC4626(UNDERLYING_ASSET).convertToAssets(assetAmount); // round down
    return
      vaultAssets.mulDiv(
        PRICE_RATIO,
        _underlyingAssetUnits,
        roundUp ? Math.Rounding.Up : Math.Rounding.Down
      );
  }

  /// @inheritdoc IGsmPriceStrategy
  function getGhoPriceInAsset(uint256 ghoAmount, bool roundUp) external view returns (uint256) {
    uint256 vaultAssets = ghoAmount.mulDiv(
      _underlyingAssetUnits,
      PRICE_RATIO,
      roundUp ? Math.Rounding.Up : Math.Rounding.Down
    );
    // conversion of 4626 assets to 4626 shares
    return
      roundUp
        ? IERC4626(UNDERLYING_ASSET).previewWithdraw(vaultAssets) // round up
        : IERC4626(UNDERLYING_ASSET).convertToShares(vaultAssets); // round down
  }
}

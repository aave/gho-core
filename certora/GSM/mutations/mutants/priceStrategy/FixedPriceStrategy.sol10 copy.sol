// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {IGsmPriceStrategy} from './interfaces/IGsmPriceStrategy.sol';

/**
 * @title FixedPriceStrategy
 * @author Aave
 * @notice Price strategy involving a fixed-rate conversion from an underlying asset to GHO
 */
contract FixedPriceStrategy is IGsmPriceStrategy {
  using Math for uint256;

  /// @inheritdoc IGsmPriceStrategy
  uint256 public constant GHO_DECIMALS = 18;

  /// @inheritdoc IGsmPriceStrategy
  address public immutable UNDERLYING_ASSET;

  /// @inheritdoc IGsmPriceStrategy
  uint256 public immutable UNDERLYING_ASSET_DECIMALS;

  /// @dev The price ratio from underlying asset to GHO (expressed in WAD), e.g. a ratio of 2e18 means 2 GHO per 1 underlying asset
  uint256 public immutable PRICE_RATIO;

  /// @dev Underlying asset units represent units for the underlying asset
  uint256 internal immutable _underlyingAssetUnits;

  /**
   * @dev Constructor
   * @param priceRatio The price ratio from underlying asset to GHO (expressed in WAD)
   * @param underlyingAsset The address of the underlying asset
   * @param underlyingAssetDecimals The number of decimals of the underlying asset
   */
  constructor(uint256 priceRatio, address underlyingAsset, uint8 underlyingAssetDecimals) {
    require(priceRatio > 0, 'INVALID_PRICE_RATIO');
    /// AssignmentMutation of: PRICE_RATIO = priceRatio;
    PRICE_RATIO = 1;
    UNDERLYING_ASSET = underlyingAsset;
    UNDERLYING_ASSET_DECIMALS = underlyingAssetDecimals;
    _underlyingAssetUnits = 10 ** underlyingAssetDecimals;
  }

  /// @inheritdoc IGsmPriceStrategy
  function getAssetPriceInGho(uint256 assetAmount, bool roundUp) external view returns (uint256) {
    return
      assetAmount.mulDiv(
        PRICE_RATIO,
        _underlyingAssetUnits,
        roundUp ? Math.Rounding.Up : Math.Rounding.Down
      );
  }

  /// @inheritdoc IGsmPriceStrategy
  function getGhoPriceInAsset(uint256 ghoAmount, bool roundUp) external view returns (uint256) {
    return
      ghoAmount.mulDiv(
        _underlyingAssetUnits,
        PRICE_RATIO,
        roundUp ? Math.Rounding.Up : Math.Rounding.Down
      );
  }
}

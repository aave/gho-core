pragma solidity ^0.8.0;

import {FixedPriceStrategy} from '../../../src/contracts/facilitators/gsm/priceStrategy/FixedPriceStrategy.sol';

contract FixedPriceStrategyHarness is FixedPriceStrategy {
  constructor(
    uint256 priceRatio,
    address underlyingAsset,
    uint8 underlyingAssetDecimals
  ) FixedPriceStrategy(priceRatio, underlyingAsset, underlyingAssetDecimals) {}

  function getUnderlyingAssetUnits() external view returns (uint256) {
    return _underlyingAssetUnits;
  }

  function getUnderlyginAssetDecimals() external view returns (uint256) {
    return UNDERLYING_ASSET_DECIMALS;
  }

  function getPriceRatio() external view returns (uint256) {
    return PRICE_RATIO;
  }
}

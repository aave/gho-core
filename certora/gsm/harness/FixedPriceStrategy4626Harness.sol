pragma solidity ^0.8.0;

import {FixedPriceStrategy4626} from '../../../src/contracts/facilitators/gsm/priceStrategy/FixedPriceStrategy4626.sol';

contract FixedPriceStrategy4626Harness is FixedPriceStrategy4626 {
  constructor(
    uint256 priceRatio,
    address underlyingAsset,
    uint8 underlyingAssetDecimals
  ) FixedPriceStrategy4626(priceRatio, underlyingAsset, underlyingAssetDecimals) {}

  function getUnderlyingAssetUnits() external view returns (uint256) {
    return _underlyingAssetUnits;
  }

  function getPriceRatio() external view returns (uint256) {
    return PRICE_RATIO;
  }
}

pragma solidity ^0.8.0;

import {Gsm4626} from '../../../src/contracts/facilitators/gsm/Gsm4626.sol';
import {IGhoToken} from '../../../src/contracts/gho/interfaces/IGhoToken.sol';
import {IGsmPriceStrategy} from '../../../src/contracts/facilitators/gsm/priceStrategy/interfaces/IGsmPriceStrategy.sol';
import {FixedPriceStrategy4626Harness} from './FixedPriceStrategy4626Harness.sol';
import {FixedFeeStrategyHarness} from './FixedFeeStrategyHarness.sol';
import {IGsmFeeStrategy} from '../../../src/contracts/facilitators/gsm/feeStrategy/interfaces/IGsmFeeStrategy.sol';
import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';

contract Gsm4626Harness is Gsm4626 {
  constructor(
    address ghoToken,
    address underlyingAsset,
    address priceStrategy
  ) Gsm4626(ghoToken, underlyingAsset, priceStrategy) {}

  function getAccruedFee() external view returns (uint256) {
    return _accruedFees;
  }

  function getCurrentExposure() external view returns (uint256) {
    return _currentExposure;
  }

  function getGhoMinted() public view returns (uint256 ghoMinted) {
    (, ghoMinted) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(address(this));
  }

  function getDearth() external view returns (uint256 dearth) {
    (, dearth) = _getCurrentBacking(getGhoMinted());
  }

  function getExcess() external view returns (uint256 excess) {
    (excess, ) = _getCurrentBacking(getGhoMinted());
  }

  function getPriceRatio() external returns (uint256 priceRatio) {
    priceRatio = FixedPriceStrategy4626Harness(PRICE_STRATEGY).PRICE_RATIO();
  }

  function getAssetPriceInGho(uint256 amount, bool roundUp) external returns (uint256 priceInGho) {
    priceInGho = IGsmPriceStrategy(PRICE_STRATEGY).getAssetPriceInGho(amount, roundUp);
  }

  function getUnderlyingAssetUnits() external returns (uint256 underlyingAssetUnits) {
    underlyingAssetUnits = FixedPriceStrategy4626Harness(PRICE_STRATEGY).getUnderlyingAssetUnits();
  }

  function zeroModulo(uint256 x, uint256 y, uint256 z) external pure {
    require((x * y) % z == 0);
  }

  function getBuyFeeBP() external returns (uint256) {
    return FixedFeeStrategyHarness(_feeStrategy).getBuyFeeBP();
  }

  function getSellFeeBP() external returns (uint256) {
    return FixedFeeStrategyHarness(_feeStrategy).getSellFeeBP();
  }

  function getPercMathPercentageFactor() external view returns (uint256) {
    return FixedFeeStrategyHarness(_feeStrategy).getPercMathPercentageFactor();
  }

  function getCurrentGhoBalance() external view returns (uint256) {
    return IERC20(GHO_TOKEN).balanceOf(address(this));
  }

  function getCurrentUnderlyingBalance() external view returns (uint256) {
    return IERC20(UNDERLYING_ASSET).balanceOf(address(this));
  }

  function giftGho(address sender, uint amount) external {
    IGhoToken(GHO_TOKEN).transferFrom(sender, address(this), amount);
  }

  function giftUnderlyingAsset(address sender, uint amount) external {
    IERC20(UNDERLYING_ASSET).transferFrom(sender, address(this), amount);
  }

  function getSellFee(uint256 amount) external returns (uint256) {
    return IGsmFeeStrategy(_feeStrategy).getSellFee(amount);
  }

  function getBuyFee(uint256 amount) external returns (uint256) {
    return IGsmFeeStrategy(_feeStrategy).getBuyFee(amount);
  }

  function balanceOfUnderlying(address a) external view returns (uint256) {
    return IERC20(UNDERLYING_ASSET).balanceOf(a);
  }

  function balanceOfGho(address a) external view returns (uint256) {
    return IGhoToken(GHO_TOKEN).balanceOf(a);
  }

  function getGhoBalanceOfThis() external view returns (uint256) {
    return IGhoToken(GHO_TOKEN).balanceOf(address(this));
  }

  function getExceed() external view returns (uint256 exceed) {
    (exceed, ) = _getCurrentBacking(getGhoMinted());
  }

  function cumulateYieldInGho() external {
    _cumulateYieldInGho();
  }

  function balanceOfUnderlyingDirect(address a) external view returns (uint256) {
    return IERC4626(UNDERLYING_ASSET).balanceOf(a);
  }

  function getFacilitatorBucket() public view returns (uint256 ghoBucketLevel, uint256 ghoMinted) {
    (ghoBucketLevel, ghoMinted) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(address(this));
  }

  function getUnderlyingAssetDecimals() external returns (uint256 underlyingAssetDecimals) {
    underlyingAssetDecimals = IGsmPriceStrategy(PRICE_STRATEGY).UNDERLYING_ASSET_DECIMALS();
  }
}

pragma solidity ^0.8.0;

import {Gsm} from '../../../src/contracts/facilitators/gsm/Gsm.sol';
import {IGhoToken} from '../../../src/contracts/gho/interfaces/IGhoToken.sol';
import {IGsmPriceStrategy} from '../../../src/contracts/facilitators/gsm/priceStrategy/interfaces/IGsmPriceStrategy.sol';
import {IGsmFeeStrategy} from '../../../src/contracts/facilitators/gsm/feeStrategy/interfaces/IGsmFeeStrategy.sol';
import {FixedPriceStrategyHarness} from './FixedPriceStrategyHarness.sol';
import {FixedFeeStrategyHarness} from './FixedFeeStrategyHarness.sol';
import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';

contract GsmHarness is Gsm {
  constructor(
    address ghoToken,
    address underlyingAsset,
    address priceStrategy
  ) Gsm(ghoToken, underlyingAsset, priceStrategy) {}

  function getAccruedFee() external view returns (uint256) {
    return _accruedFees;
  }

  function getCurrentExposure() external view returns (uint128) {
    return _currentExposure;
  }

  function getGhoMinted() public view returns (uint256 ghoMinted) {
    (, ghoMinted) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(address(this));
  }

  function getPriceRatio() external returns (uint256 priceRatio) {
    priceRatio = FixedPriceStrategyHarness(PRICE_STRATEGY).PRICE_RATIO();
  }

  function getUnderlyingAssetUnits() external returns (uint256 underlyingAssetUnits) {
    underlyingAssetUnits = FixedPriceStrategyHarness(PRICE_STRATEGY).getUnderlyingAssetUnits();
  }

  function getUnderlyingAssetDecimals() external returns (uint256 underlyingAssetDecimals) {
    underlyingAssetDecimals = IGsmPriceStrategy(PRICE_STRATEGY).UNDERLYING_ASSET_DECIMALS();
  }

  function getAssetPriceInGho(uint256 amount, bool roundUp) external returns (uint256 priceInGho) {
    priceInGho = IGsmPriceStrategy(PRICE_STRATEGY).getAssetPriceInGho(amount, roundUp);
  }

  function zeroModulo(uint256 x, uint256 y, uint256 z) external pure {
    require((x * y) % z == 0);
  }

  function getSellFee(uint256 amount) external returns (uint256) {
    return IGsmFeeStrategy(_feeStrategy).getSellFee(amount);
  }

  function getBuyFee(uint256 amount) external returns (uint256) {
    return IGsmFeeStrategy(_feeStrategy).getBuyFee(amount);
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

  function balanceOfUnderlying(address a) external view returns (uint256) {
    return IERC20(UNDERLYING_ASSET).balanceOf(a);
  }

  function balanceOfGho(address a) external view returns (uint256) {
    return IGhoToken(GHO_TOKEN).balanceOf(a);
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

  function getGhoBalanceOfThis() external view returns (uint256) {
    return IGhoToken(GHO_TOKEN).balanceOf(address(this));
  }
}

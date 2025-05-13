// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from '@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {GPv2SafeERC20} from '@aave/core-v3/contracts/dependencies/gnosis/contracts/GPv2SafeERC20.sol';
import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {IGhoFacilitator} from '../../gho/interfaces/IGhoFacilitator.sol';
import {IGhoToken} from '../../gho/interfaces/IGhoToken.sol';
import {IGsmPriceStrategy} from './priceStrategy/interfaces/IGsmPriceStrategy.sol';
import {IGsm4626} from './interfaces/IGsm4626.sol';
import {IGhoReserve} from './interfaces/IGhoReserve.sol';
import {Gsm} from './Gsm.sol';

/**
 * @title Gsm4626
 * @author Aave
 * @notice GHO Stability Module for ERC4626 vault shares. It provides buy/sell facilities to go to/from an ERC4626
 * vault share to/from GHO.
 * @dev Aimed to be used with ERC4626 vault shares as underlying asset. Users can use the ERC4626 vault share to
 * buy/sell GHO and the generated yield is redirected to the GHO Treasury in form of GHO.
 * @dev To be covered by a proxy contract.
 */
contract Gsm4626 is Gsm, IGsm4626 {
  using GPv2SafeERC20 for IERC20;
  using SafeCast for uint256;

  /**
   * @dev Constructor
   * @param ghoToken The address of the GHO token contract
   * @param underlyingAsset The address of the ERC4626 vault
   * @param priceStrategy The address of the price strategy
   */
  constructor(
    address ghoToken,
    address underlyingAsset,
    address priceStrategy
  ) Gsm(ghoToken, underlyingAsset, priceStrategy) {
    // Intentionally left blank
  }

  /// @inheritdoc IGsm4626
  function backWithGho(
    uint256 amount
  ) external notSeized onlyRole(CONFIGURATOR_ROLE) returns (uint256) {
    require(amount > 0, 'INVALID_AMOUNT');

    uint256 ghoUsed = _getUsedGho();
    (, uint256 deficit) = _getCurrentBacking(ghoUsed);
    require(deficit > 0, 'NO_CURRENT_DEFICIT_BACKING');

    uint256 ghoToBack = amount > deficit ? deficit : amount;

    IGhoToken(GHO_TOKEN).transferFrom(msg.sender, address(this), ghoToBack);
    IGhoReserve(_ghoReserve).restoreGho(ghoToBack);

    emit BackingProvided(msg.sender, GHO_TOKEN, ghoToBack, ghoToBack, deficit - ghoToBack);
    return ghoToBack;
  }

  /// @inheritdoc IGsm4626
  function backWithUnderlying(
    uint256 amount
  ) external notSeized onlyRole(CONFIGURATOR_ROLE) returns (uint256) {
    require(amount > 0, 'INVALID_AMOUNT');

    uint256 ghoUsed = _getUsedGho();
    (, uint256 deficit) = _getCurrentBacking(ghoUsed);
    require(deficit > 0, 'NO_CURRENT_DEFICIT_BACKING');

    uint128 deficitInUnderlying = IGsmPriceStrategy(PRICE_STRATEGY)
      .getGhoPriceInAsset(deficit, false)
      .toUint128();

    if (amount >= deficitInUnderlying) {
      _currentExposure += deficitInUnderlying;
      IERC20(UNDERLYING_ASSET).safeTransferFrom(msg.sender, address(this), deficitInUnderlying);

      emit BackingProvided(msg.sender, UNDERLYING_ASSET, deficitInUnderlying, deficit, 0);
      return deficitInUnderlying;
    } else {
      uint256 amountInGho = IGsmPriceStrategy(PRICE_STRATEGY).getAssetPriceInGho(amount, false);

      _currentExposure += uint128(amount);
      IERC20(UNDERLYING_ASSET).safeTransferFrom(msg.sender, address(this), amount);

      emit BackingProvided(
        msg.sender,
        UNDERLYING_ASSET,
        amount,
        amountInGho,
        deficit - amountInGho
      );
      return amount;
    }
  }

  /// @inheritdoc IGsm4626
  function getCurrentBacking() external view returns (uint256, uint256) {
    uint256 ghoUsed = _getUsedGho();
    return _getCurrentBacking(ghoUsed);
  }

  /// @inheritdoc IGhoFacilitator
  function distributeFeesToTreasury() public override(Gsm, IGhoFacilitator) {
    _cumulateYieldInGho();
    super.distributeFeesToTreasury();
  }

  /// @inheritdoc Gsm
  function _beforeBuyAsset(address, uint256, address) internal override {
    _cumulateYieldInGho();
  }

  /// @inheritdoc Gsm
  function _beforeSellAsset(address, uint256, address) internal override {}

  /**
   * @dev Cumulates yield in form of GHO, aimed to be redirected to the treasury
   * @dev It mints GHO backed by the excess of underlying produced by the ERC4626 yield
   * @dev If the GHO amount exceeds the amount available, it will mint up to the remaining capacity
   */
  function _cumulateYieldInGho() internal {
    uint256 ghoLevel = _getUsedGho();
    uint256 ghoCapacity = _getCapacity();
    uint256 ghoAvailableToMint = ghoCapacity > ghoLevel ? ghoCapacity - ghoLevel : 0;
    (uint256 ghoExcess, ) = _getCurrentBacking(ghoLevel);
    if (ghoExcess > 0 && ghoAvailableToMint > 0) {
      ghoExcess = ghoExcess > ghoAvailableToMint ? ghoAvailableToMint : ghoExcess;
      _accruedFees += uint128(ghoExcess);
      IGhoReserve(_ghoReserve).useGho(ghoExcess);
    }
  }

  /**
   * @dev Calculates the excess or deficit of GHO minted, reflective of GSM backing
   * @param ghoUsed The amount of GHO currently used by the GSM
   * @return The excess amount of GHO used, relative to the value of the underlying
   * @return The deficit of GHO used, relative to the value of the underlying
   */
  function _getCurrentBacking(uint256 ghoUsed) internal view returns (uint256, uint256) {
    uint256 ghoToBack = IGsmPriceStrategy(PRICE_STRATEGY).getAssetPriceInGho(
      _currentExposure,
      false
    );
    if (ghoToBack >= ghoUsed) {
      return (ghoToBack - ghoUsed, 0);
    } else {
      return (0, ghoUsed - ghoToBack);
    }
  }
}

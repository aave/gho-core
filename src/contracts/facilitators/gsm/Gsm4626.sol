// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGhoFacilitator} from '../../gho/interfaces/IGhoFacilitator.sol';
import {IGhoToken} from '../../gho/interfaces/IGhoToken.sol';
import {IGsmPriceStrategy} from './priceStrategy/interfaces/IGsmPriceStrategy.sol';
import {Gsm} from './Gsm.sol';

/**
 * @title Gsm4626
 * @author Aave
 * @notice GHO Stability Module for ERC4626 assets. It provides buy/sell facilities to go to/from an ERC4626 asset
 * to/from GHO.
 * @dev Aimed to be used with ERC4626 assets as underlying asset. Users can use the ERC4626 asset to
 * buy/sell GHO and the generated yield is redirected to the GHO Treasury in form of GHO.
 * @dev To be covered by a proxy contract.
 */
contract Gsm4626 is Gsm {
  /**
   * @dev Constructor
   * @param ghoToken The address of the GHO token contract
   * @param underlyingAsset The address of the collateral asset
   */
  constructor(address ghoToken, address underlyingAsset) Gsm(ghoToken, underlyingAsset) {
    // Intentionally left blank
  }

  /// @inheritdoc Gsm
  function updatePriceStrategy(address priceStrategy) public override {
    // Cumulates yield based on the current price strategy before updating
    // Note that the accrual can be skipped in case the capacity is maxed out
    // A temporary increase of the bucket capacity facilitates the fee accrual
    _cumulateYieldInGho();

    super.updatePriceStrategy(priceStrategy);
  }

  /// @inheritdoc IGhoFacilitator
  function distributeFeesToTreasury() public override {
    _cumulateYieldInGho();
    super.distributeFeesToTreasury();
  }

  /// @inheritdoc Gsm
  function _beforeBuyAsset(address, uint128, address) internal override {
    _cumulateYieldInGho();
  }

  /// @inheritdoc Gsm
  function _beforeSellAsset(address, uint128, address) internal override {}

  /**
   * @dev Cumulates yield in form of GHO, aimed to be redirected to the treasury
   * @dev It mints GHO backed by the excess of underlying produced by the ERC4626 yield
   * @dev It skips the mint in case the bucket level reaches the maximum capacity
   */
  function _cumulateYieldInGho() internal {
    (uint256 ghoCapacity, uint256 ghoLevel) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(
      address(this)
    );
    uint256 ghoAvailableToMint = ghoCapacity > ghoLevel ? ghoCapacity - ghoLevel : 0;
    (uint256 ghoExcess, ) = _getCurrentBacking(ghoLevel);
    if (ghoAvailableToMint >= ghoExcess && ghoExcess > 0) {
      _accruedFees += uint128(ghoExcess);
      IGhoToken(GHO_TOKEN).mint(address(this), ghoExcess);
    }
  }
}

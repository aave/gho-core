// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IGhoToken} from '../../gho/interfaces/IGhoToken.sol';
import {IRemoteGsm} from './interfaces/IRemoteGsm.sol';
import {GhoRemoteReserve} from './GhoRemoteReserve.sol';
import {Gsm} from './Gsm.sol';

/**
 * @title RemoteGsm
 * @author Aave
 * @notice Remote GHO Stability Module. It provides buy/sell facilities to go to/from an underlying asset to/from GHO.
 * @dev To be covered by a proxy contract.
 */
contract RemoteGsm is IRemoteGsm, Gsm {
  address internal _ghoReserve;

  /**
   * @dev Constructor
   * @param ghoToken The address of the GHO token contract
   * @param underlyingAsset The address of the collateral asset
   * @param priceStrategy The address of the price strategy
   * @param ghoReserve Address of the GHO reserve to fund GSM trades
   */
  constructor(
    address ghoToken,
    address underlyingAsset,
    address priceStrategy,
    address ghoReserve
  ) Gsm(ghoToken, underlyingAsset, priceStrategy) {
    _updateGhoReserve(ghoReserve);
  }

  /// @inheritdoc IRemoteGsm
  function updateGhoReserve(address ghoReserve) external onlyRole(CONFIGURATOR_ROLE) {
    _updateGhoReserve(ghoReserve);
  }

  /// @inheritdoc IRemoteGsm
  function getGhoReserve() external view returns (address) {
    return _ghoReserve;
  }

  /// @inheritdoc Gsm
  function _restoreGho(address originator, uint256 grossAmount) internal override {
    GhoRemoteReserve(_ghoReserve).returnGho(grossAmount);
  }

  /// @inheritdoc Gsm
  function _useGho(uint256 grossAmount) internal override {
    GhoRemoteReserve(_ghoReserve).withdrawGho(grossAmount);
  }

  /// @inheritdoc Gsm
  function _burnGhoAfterSeize(uint256 amount) internal override {
    GhoRemoteReserve(_ghoReserve).returnGho(amount);
    GhoRemoteReserve(_ghoReserve).bridgeGho(amount);
  }

  /// @inheritdoc Gsm
  function _getUsedGho() internal view override returns (uint256) {
    return GhoRemoteReserve(_ghoReserve).getWithdrawnGho(address(this));
  }

  /**
   * @dev Updates address of GHO reserve
   * @param ghoReserve The address of the GHO reserve for the GSM
   */
  function _updateGhoReserve(address ghoReserve) internal {
    require(ghoReserve != address(0), 'ZERO_ADDRESS_NOT_VALID');
    address oldReserve = _ghoReserve;
    _ghoReserve = ghoReserve;

    IGhoToken(GHO_TOKEN).approve(oldReserve, 0);
    IGhoToken(GHO_TOKEN).approve(ghoReserve, type(uint256).max);

    emit GhoReserveUpdated(oldReserve, ghoReserve);
  }
}

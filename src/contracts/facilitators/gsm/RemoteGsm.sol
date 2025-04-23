// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IGhoToken} from '../../gho/interfaces/IGhoToken.sol';
import {IRemoteGsm} from './interfaces/IRemoteGsm.sol';
import {GhoRemoteVault} from './GhoRemoteVault.sol';
import {Gsm} from './Gsm.sol';

/**
 * @title RemoteGsm
 * @author Aave
 * @notice Remote GHO Stability Module. It provides buy/sell facilities to go to/from an underlying asset to/from GHO.
 * @dev To be covered by a proxy contract.
 */
contract RemoteGsm is IRemoteGsm, Gsm {
  address internal _ghoVault;

  /**
   * @dev Constructor
   * @param ghoToken The address of the GHO token contract
   * @param underlyingAsset The address of the collateral asset
   * @param priceStrategy The address of the price strategy
   * @param ghoVault Address of the GHO vault to fund GSM trades
   */
  constructor(
    address ghoToken,
    address underlyingAsset,
    address priceStrategy,
    address ghoVault
  ) Gsm(ghoToken, underlyingAsset, priceStrategy) {
    _updateGhoVault(ghoVault);
  }

  /// @inheritdoc IRemoteGsm
  function updateGhoVault(address ghoVault) external onlyRole(CONFIGURATOR_ROLE) {
    _updateGhoVault(ghoVault);
  }

  /// @inheritdoc IRemoteGsm
  function getGhoVault() external view returns (address) {
    return _ghoVault;
  }

  /// @inheritdoc Gsm
  function _restoreGho(address originator, uint256 grossAmount) internal override {
    GhoRemoteVault(_ghoVault).returnGho(grossAmount);
  }

  /// @inheritdoc Gsm
  function _useGho(uint256 grossAmount) internal override {
    GhoRemoteVault(_ghoVault).withdrawGho(grossAmount);
  }

  /// @inheritdoc Gsm
  function _burnGhoAfterSeize(uint256 amount) internal override {
    GhoRemoteVault(_ghoVault).returnGho(amount);
    GhoRemoteVault(_ghoVault).bridgeGho(amount);
  }

  /// @inheritdoc Gsm
  function _getUsedGho() internal view override returns (uint256) {
    return GhoRemoteVault(_ghoVault).getWithdrawnGho(address(this));
  }

  /**
   * @dev Updates address of GHO Vault
   * @param ghoVault The address of the GHO vault for the GSM
   */
  function _updateGhoVault(address ghoVault) internal {
    require(ghoVault != address(0), 'ZERO_ADDRESS_NOT_VALID');
    address oldVault = _ghoVault;
    _ghoVault = ghoVault;

    IGhoToken(GHO_TOKEN).approve(oldVault, 0);
    IGhoToken(GHO_TOKEN).approve(ghoVault, type(uint256).max);

    emit GhoVaultUpdated(oldVault, ghoVault);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IGhoToken} from '../../gho/interfaces/IGhoToken.sol';
import {IRemoteGsm} from './interfaces/IRemoteGsm.sol';
import {MockCollector} from '../../../test/mocks/MockCollector.sol';
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
  function _handleGhoSold(
    address originator,
    uint256 ghoSold,
    uint256 grossAmount
  ) internal override {
    IGhoToken(GHO_TOKEN).transferFrom(originator, address(this), ghoSold);
    MockCollector(_ghoVault).payBackGho(grossAmount);
  }

  /// @inheritdoc Gsm
  function _handleGhoBought(address receiver, uint256 ghoBought, uint256 fee) internal override {
    MockCollector(_ghoVault).transferGho(address(this), fee);
    MockCollector(_ghoVault).transferGho(receiver, ghoBought);
  }

  /// @inheritdoc Gsm
  function _handleGhoBurnAfterSeize(uint256 amount) internal override {
    IGhoToken(GHO_TOKEN).transferFrom(msg.sender, address(this), amount);
    MockCollector(_ghoVault).payBackGho(amount);
    MockCollector(_ghoVault).bridgeGho(amount);
  }

  /// @inheritdoc Gsm
  function _getGhoOutstanding() internal view override returns (uint256) {
    return MockCollector(_ghoVault).ghoOutstanding();
  }

  /**
   * @dev Updates address of GHO Vault
   * @param ghoVault The address of the GHO vault for the GSM
   */
  function _updateGhoVault(address ghoVault) internal {
    require(ghoVault != address(0), 'ZERO_ADDRESS_NOT_VALID');
    address oldVault = _ghoVault;
    _ghoVault = ghoVault;
    emit GhoVaultUpdated(oldVault, ghoVault);
  }
}

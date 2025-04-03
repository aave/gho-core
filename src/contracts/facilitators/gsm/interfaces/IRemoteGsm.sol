// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IGsm} from './IGsm.sol';

/**
 * @title IRemoteGsm
 * @author Aave
 * @notice Defines the behaviour of a Remote GHO Stability Module
 */
interface IRemoteGsm is IGsm {
  /**
   * @dev Emitted when the GSM's vault is updated
   * @param oldVault The address of the old vault
   * @param newVault The address of the new vault
   */
  event GhoVaultUpdated(address oldVault, address newVault);

  /**
   * Returns the address of the GHO vault
   */
  function getGhoVault() external view returns (address);

  /**
   * @notice Updates the GHO vault address
   * @param ghoVault The new address of the vault holding GHO
   */
  function updateGhoVault(address ghoVault) external;
}

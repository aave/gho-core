// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

import {IAToken} from '@aave/core-v3/contracts/interfaces/IAToken.sol';

/**
 * @title IGhoAToken
 * @author Aave
 * @notice Defines the basic interface of the GhoAToken
 */
interface IGhoAToken is IAToken {
  /**
   * @dev Emitted when variable debt contract is set
   * @param oldVariableDebtToken The address of the old GhoTreasury
   * @param newVariableDebtToken The address of the GhoVariableDebtToken contract
   **/
  event VariableDebtTokenSet(
    address indexed oldVariableDebtToken,
    address indexed newVariableDebtToken
  );

  /**
   * @dev Emitted when GHO treasury address is updated
   * @param oldGhoTreasury The address of the old GhoTreasury
   * @param newGhoTreasury The address of the new GhoTreasury
   **/
  event GhoTreasuryUpdated(address indexed oldGhoTreasury, address indexed newGhoTreasury);

  /**
   * @notice Sets a reference to the GHO variable debt token
   * @param ghoVariableDebtToken The address of the GhoVariableDebtToken contract
   **/
  function setVariableDebtToken(address ghoVariableDebtToken) external;

  /**
   * @notice Returns the address of the GHO variable debt token
   * @return The address of the GhoVariableDebtToken contract
   **/
  function getVariableDebtToken() external view returns (address);

  /**
   * @notice Updates the address of the GHO treasury, where interest earned by the protocol is sent
   * @param newGhoTreasury The address of the GhoTreasury
   **/
  function updateGhoTreasury(address newGhoTreasury) external;

  /**
   * @notice Returns the address of the GHO treasury
   * @return The address of the GhoTreasury contract
   **/
  function getGhoTreasury() external view returns (address);
}

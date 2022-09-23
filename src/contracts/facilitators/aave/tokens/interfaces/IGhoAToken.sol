// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

import {IAToken} from '@aave/core-v3/contracts/interfaces/IAToken.sol';

interface IGhoAToken is IAToken {
  /**
   * @dev Emitted when variable debt contract is set
   * @dev This must be the proxy contract
   * @param variableDebtToken GhoVariableDebtToken contract
   **/
  event VariableDebtTokenSet(address indexed variableDebtToken);

  /**
   * @dev Emitted when GHO treasury address is updated
   * @param previousGhoTreasury previous treasury address
   * @param newGhoTreasury new treasury address
   **/
  event GhoTreasuryUpdated(address indexed previousGhoTreasury, address indexed newGhoTreasury);

  /**
   * @dev Sets a reference to the GhoVariableDebtToken contract
   * @dev Only callable by the pool admin
   * @param ghoVariableDebtAddress GhoVariableDebtToken contract address
   **/
  function setVariableDebtToken(address ghoVariableDebtAddress) external;

  /**
   * @dev Return the address of the GhoVariableDebtToken contract
   **/
  function getVariableDebtToken() external view returns (address);

  /**
   * @dev Sets a reference to the Gho treasury contract
   * @dev Only callable by the pool admin
   * @param newGhoTreasury address to direct interest earned by the protocol
   **/
  function setGhoTreasury(address newGhoTreasury) external;

  /**
   * @dev Return the address of the Gho treasury contract
   **/
  function getGhoTreasury() external view returns (address);
}

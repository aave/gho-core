// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;

import {IAToken} from '../../../poolUpgrade/IAToken.sol';

interface IGhoAToken is IAToken {
  /**
   * @dev Emitted when variable debt contract is set
   * @dev This must be the proxy contract
   * @param variableDebtToken GhoVariableDebtToken contract
   **/
  event VariableDebtTokenSet(address indexed variableDebtToken);

  /**
   * @dev Emitted when treasury address is updated
   * @param previousTreasury previous treasury address
   * @param newTreasury new treasury address
   **/
  event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);

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
   * @param newTreasury address to direct interest earned by the protocol
   **/
  function setTreasury(address newTreasury) external;

  /**
   * @dev Return the address of the Gho treasury contract
   **/
  function getTreasury() external view returns (address);
}

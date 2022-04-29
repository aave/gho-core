// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IAToken} from '../../../poolUpgrade/IAToken.sol';

interface IAnteiAToken is IAToken {
  /**
   * @dev Emitted when variable debt contract is set
   * @dev This must be the proxy contract
   * @param variableDebtToken Antei VariableDebtToken contract
   **/
  event VariableDebtTokenSet(address indexed variableDebtToken);

  /**
   * @dev Emitted when treasury address is updated
   * @param previousTreasury previous treasury address
   * @param newTreasury new treasury address
   **/
  event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);

  /**
   * @dev Sets a reference to the Antei VariableDebtToken contract
   * @dev Only callable by the pool admin
   * @param anteiVariableDebtAddress Antei VariableDebtToken contract address
   **/
  function setVariableDebtToken(address anteiVariableDebtAddress) external;

  /**
   * @dev Return the address of the Antei VariableDebtToken contract
   **/
  function getVariableDebtToken() external view returns (address);

  /**
   * @dev Sets a reference to the Antei treasury contract
   * @dev Only callable by the pool admin
   * @param newTreasury address to direct interest earned by the protocol
   **/
  function setTreasury(address newTreasury) external;


  /**
   * @dev Return the address of the Antei treasury contract
   **/
  function getTreasury() external view returns (address);
}


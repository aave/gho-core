// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IAToken} from '@aave/core-v3/contracts/interfaces/IAToken.sol';
import {IGhoFacilitator} from '../../../../gho/interfaces/IGhoFacilitator.sol';

/**
 * @title IGhoAToken
 * @author Aave
 * @notice Defines the basic interface of the GhoAToken
 */
interface IGhoAToken is IAToken, IGhoFacilitator {
  /**
   * @dev Emitted when variable debt contract is set
   * @param variableDebtToken The address of the GhoVariableDebtToken contract
   */
  event VariableDebtTokenSet(address indexed variableDebtToken);

  /**
   * @notice Sets a reference to the GHO variable debt token
   * @param ghoVariableDebtToken The address of the GhoVariableDebtToken contract
   */
  function setVariableDebtToken(address ghoVariableDebtToken) external;

  /**
   * @notice Returns the address of the GHO variable debt token
   * @return The address of the GhoVariableDebtToken contract
   */
  function getVariableDebtToken() external view returns (address);
}

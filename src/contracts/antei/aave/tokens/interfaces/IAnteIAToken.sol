// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IAToken} from '@aave/protocol-v2/contracts/interfaces/IAToken.sol';

interface IAnteiAToken is IAToken {
  /**
   * @dev Emitted when variable debt contract is set
   * @dev This must be the proxy contract
   * @param variableDebtContract Antei VariableDebtToken contract
   **/
  event VariableDebtTokenSet(address indexed variableDebtContract);

  /**
   * @dev Emitted when treasury address is updated
   * @param previousTreasury previous treasury address
   * @param newTreasury new treasury address
   **/
  event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
}


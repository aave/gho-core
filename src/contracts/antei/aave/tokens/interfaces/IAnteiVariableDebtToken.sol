// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IVariableDebtToken} from '@aave/protocol-v2/contracts/interfaces/IVariableDebtToken.sol';

interface IAnteiVariableDebtToken is IVariableDebtToken {

    /**
   * @dev Emitted when variable debt contract is set
   * @dev This must be the proxy contract
   * @param aToken Antei aToken contract
   **/
  event ATokenSet(address indexed aToken);

}
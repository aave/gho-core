pragma solidity 0.8.10;

import {GhoVariableDebtTokenHarness} from './ghoVariableDebtTokenHarness.sol';
import {GhoVariableDebtToken} from '../munged/contracts/facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';

contract GhoVariableDebtTokenHarnessInternal is GhoVariableDebtTokenHarness {
  constructor(IPool pool) public GhoVariableDebtTokenHarness(pool) {
    //nop
  }

  function accrueDebtOnAction(
    address user,
    uint256 previousScaledBalance,
    uint256 discountPercent,
    uint256 index
  ) external returns (uint256, uint256) {
    return _accrueDebtOnAction(user, previousScaledBalance, discountPercent, index);
  }
}

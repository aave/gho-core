// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import './TestEnv.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {DebtUtils} from './libraries/DebtUtils.sol';
import {GhoActions} from './libraries/GhoActions.sol';

contract TestGhoOracle is Test, GhoActions {
  int256 constant DEFAULT_GHO_PRICE = 1e8;
  uint8 constant DEFAULT_ORACLE_DECIMALS = 8;

  function testLatestAnswer() public {
    int256 latest = GHO_ORACLE.latestAnswer();
    assertEq(latest, DEFAULT_GHO_PRICE, 'Wrong GHO price from oracle');
  }

  function testDecimals() public {
    uint8 decimals = GHO_ORACLE.decimals();
    assertEq(decimals, DEFAULT_ORACLE_DECIMALS, 'Wrong decimals from oracle');
  }
}

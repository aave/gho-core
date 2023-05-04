// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import './TestGhoBase.t.sol';

contract TestGhoOracle is TestGhoBase {
  function testLatestAnswer() public {
    int256 latest = GHO_ORACLE.latestAnswer();
    assertEq(latest, DEFAULT_GHO_PRICE, 'Wrong GHO price from oracle');
  }

  function testDecimals() public {
    uint8 decimals = GHO_ORACLE.decimals();
    assertEq(decimals, DEFAULT_ORACLE_DECIMALS, 'Wrong decimals from oracle');
  }
}

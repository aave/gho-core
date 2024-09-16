// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {GhoGsmSteward} from '../../../src/contracts/misc/GhoGsmSteward.sol';

contract GhoGsmSteward_Harness is GhoGsmSteward {
  constructor(
    address fixedRateStrategyFactory,
    address riskCouncil
  ) GhoGsmSteward(fixedRateStrategyFactory, riskCouncil) {}
}

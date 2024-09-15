// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {GhoStewardV2} from '../../../src/contracts/misc/GhoStewardV2.sol';

contract GhoStewardV2_Harness is GhoStewardV2 {
  constructor(
    address owner,
    address addressesProvider,
    address ghoToken,
    address fixedRateStrategyFactory,
    address riskCouncil
  ) GhoStewardV2(owner, addressesProvider, ghoToken, fixedRateStrategyFactory, riskCouncil) {}

  function get_gsmFeeStrategiesByRates(
    uint256 buyFee,
    uint256 sellFee
  ) external view returns (address) {
    return _gsmFeeStrategiesByRates[buyFee][sellFee];
  }
}

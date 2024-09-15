// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {GhoCcipSteward} from '../../../src/contracts/misc/GhoCcipSteward.sol';

contract GhoCcipSteward_Harness is GhoCcipSteward {
  constructor(
    address ghoToken,
    address ghoTokenPool,
    address riskCouncil,
    bool bridgeLimitEnabled
  ) GhoCcipSteward(ghoToken, ghoTokenPool, riskCouncil, bridgeLimitEnabled) {}

  function getCcipTimelocks() external view returns (CcipDebounce memory) {
    return _ccipTimelocks;
  }


}

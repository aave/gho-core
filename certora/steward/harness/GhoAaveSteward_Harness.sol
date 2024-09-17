// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {GhoAaveSteward} from '../munged/src/contracts/misc/GhoAaveSteward.sol';

contract GhoAaveSteward_Harness is GhoAaveSteward {
  constructor(
    address owner,
    address addressesProvider,
    address poolDataProvider,
    address ghoToken,
    address riskCouncil,
    BorrowRateConfig memory borrowRateConfig
  )
    GhoAaveSteward(
      owner,
      addressesProvider,
      poolDataProvider,
      ghoToken,
      riskCouncil,
      borrowRateConfig
    )
  {}
}

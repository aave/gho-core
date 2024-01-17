// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Gsm} from '../../contracts/facilitators/gsm/Gsm.sol';

/**
 * @dev Mock contract to test GSM upgrades, not to be used in production.
 */
contract MockGsmV2 is Gsm {
  /**
   * @dev Constructor
   * @param ghoToken The address of the GHO token contract
   * @param underlyingAsset The address of the collateral asset
   * @param priceStrategy The address of the price strategy
   */
  constructor(
    address ghoToken,
    address underlyingAsset,
    address priceStrategy
  ) Gsm(ghoToken, underlyingAsset, priceStrategy) {
    // Intentionally left blank
  }

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }

  function initialize() external initializer {
    // Intentionally left blank
  }

  function GSM_REVISION() public pure virtual override returns (uint256) {
    return 2;
  }
}

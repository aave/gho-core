// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable} from 'solidity-utils/contracts/transparent-proxy/Initializable.sol';

/**
 * @dev Mock contract to test upgrades, not to be used in production.
 */
contract MockUpgradeable is Initializable {
  /**
   * @dev Constructor
   */
  constructor() {
    // Intentionally left bank
  }

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }

  /**
   * @dev Initializer
   */
  function initialize() public reinitializer(2) {
    // Intentionally left bank
  }
}

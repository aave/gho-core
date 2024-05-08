// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VersionedInitializable} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/VersionedInitializable.sol';

/**
 * @dev Mock contract to test upgrades, not to be used in production.
 */
contract MockUpgradeable is VersionedInitializable {
  /**
   * @dev Constructor
   */
  constructor() {
    // Intentionally left bank
  }

  /**
   * @dev Initializer
   */
  function initialize() public initializer {
    // Intentionally left bank
  }

  /**
   * @notice Returns the revision number
   * @return The revision number
   */
  function REVISION() public pure returns (uint256) {
    return 2;
  }

  /// @inheritdoc VersionedInitializable
  function getRevision() internal pure virtual override returns (uint256) {
    return REVISION();
  }
}

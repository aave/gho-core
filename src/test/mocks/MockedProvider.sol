// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockedProvider {
  address immutable ACL_MANAGER;

  constructor(address aclManager) {
    ACL_MANAGER = aclManager;
  }

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }

  function getACLManager() public returns (address) {
    return ACL_MANAGER;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockAclManager {
  bool state;

  constructor() {
    state = true;
  }

  function test_coverage_ignore() public virtual {
    // Intentionally left blank.
    // Excludes contract from coverage.
  }

  function setState(bool value) public {
    state = value;
  }

  function isPoolAdmin(address) public view returns (bool) {
    return state;
  }

  function isFlashBorrower(address) public view returns (bool) {
    return state;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockedAclManager {
  bool state;

  constructor() {
    state = true;
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

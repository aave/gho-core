// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockedAclManager {
  function isPoolAdmin(address) public pure returns (bool) {
    return true;
  }
}

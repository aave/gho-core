// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract DiffHelper {
  function differsByAtMostN(uint256 a, uint256 b, uint256 N) public pure returns (bool) {
    if (a > b) {
      return a - b <= N;
    } else {
      return b - a <= N;
    }
  }
}

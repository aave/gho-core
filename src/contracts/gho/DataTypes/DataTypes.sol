// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library DataTypes {

  struct Bucket {
    uint128 maxCapacity;
    uint128 level;
  }

  struct Facilitator {
    Bucket bucket;
    string label;
  }
}
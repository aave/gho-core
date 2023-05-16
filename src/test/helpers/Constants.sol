// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Constants {
  // addresses expected for BGD stkAave
  address constant SHORT_EXECUTOR = 0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;
  address constant STKAAVE_PROXY_ADMIN = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;

  // admin roles for GhoToken
  bytes32 public constant FACILITATOR_MANAGER = keccak256('FACILITATOR_MANAGER');
  bytes32 public constant BUCKET_MANAGER = keccak256('BUCKET_MANAGER');

  // defaults used in test environment
  uint256 constant DEFAULT_FLASH_FEE = 0.0009e4; // 0.09%
  uint128 constant DEFAULT_CAPACITY = 100_000_000e18;
  uint256 constant DEFAULT_BORROW_AMOUNT = 200e18;
  int256 constant DEFAULT_GHO_PRICE = 1e8;
  uint8 constant DEFAULT_ORACLE_DECIMALS = 8;

  // sample users used across unit tests
  address constant ALICE = address(0x1111);
  address constant BOB = address(0x1112);
  address constant CHARLES = address(0x1113);

  address constant FAUCET = address(0x10001);
  address constant TREASURY = address(0x10002);
}

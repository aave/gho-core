// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Constants {
  // addresses expected for BGD stkAave
  address constant SHORT_EXECUTOR = 0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;
  address constant STKAAVE_PROXY_ADMIN = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;

  // default admin role
  bytes32 public constant DEFAULT_ADMIN_ROLE = bytes32(0);

  // admin roles for GhoToken
  bytes32 public constant FACILITATOR_MANAGER_ROLE = keccak256('FACILITATOR_MANAGER_ROLE');
  bytes32 public constant BUCKET_MANAGER_ROLE = keccak256('BUCKET_MANAGER_ROLE');

  // admin role for GSM
  bytes32 public constant GSM_CONFIGURATOR_ROLE = keccak256('CONFIGURATOR_ROLE');
  bytes32 public constant GSM_TOKEN_RESCUER_ROLE = keccak256('TOKEN_RESCUER_ROLE');
  bytes32 public constant GSM_SWAP_FREEZER_ROLE = keccak256('SWAP_FREEZER_ROLE');
  bytes32 public constant GSM_LIQUIDATOR_ROLE = keccak256('LIQUIDATOR_ROLE');

  // admin role for GsmToken
  bytes32 public constant GSM_TOKEN_MINTER_ROLE = keccak256('MINTER_ROLE');

  // defaults used in test environment
  uint256 constant DEFAULT_FLASH_FEE = 0.0009e4; // 0.09%
  uint128 constant DEFAULT_CAPACITY = 100_000_000e18;
  uint256 constant DEFAULT_BORROW_AMOUNT = 200e18;
  int256 constant DEFAULT_GHO_PRICE = 1e8;
  uint8 constant DEFAULT_ORACLE_DECIMALS = 8;
  uint256 constant DEFAULT_FIXED_PRICE = 1e18;
  uint256 constant DEFAULT_GSM_BUY_FEE = 0.1e4; // 10%
  uint256 constant DEFAULT_GSM_SELL_FEE = 0.1e4; // 10%
  uint128 constant DEFAULT_GSM_USDC_EXPOSURE = 100_000_000e6; // 6 decimals for USDC
  uint128 constant DEFAULT_GSM_USDC_AMOUNT = 100e6; // 6 decimals for USDC
  uint128 constant DEFAULT_GSM_GHO_AMOUNT = 100e18;

  // GhoSteward
  uint256 constant MINIMUM_DELAY = 5 days;
  uint256 constant BORROW_RATE_CHANGE_MAX = 0.01e4;
  uint40 constant STEWARD_LIFESPAN = 90 days;

  // sample users used across unit tests
  address constant ALICE = address(0x1111);
  address constant BOB = address(0x1112);
  address constant CHARLES = address(0x1113);

  address constant FAUCET = address(0x10001);
  address constant TREASURY = address(0x10002);
  address constant RISK_COUNCIL = address(0x10003);
}

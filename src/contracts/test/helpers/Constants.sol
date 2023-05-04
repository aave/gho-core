// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Constants {
  address constant faucet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  address constant treasury = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

  // addresses expected for BGD stkAave
  address constant stkAaveExecutor = 0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;
  address constant stkAaveProxyAdmin = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;

  // defaults used in test environment
  uint256 constant DEFAULT_FLASH_FEE = 9; // 0.09%
  uint128 constant DEFAULT_CAPACITY = 100_000_000e18;
  uint256 constant DEFAULT_BORROW_AMOUNT = 200e18;
  int256 constant DEFAULT_GHO_PRICE = 1e8;
  uint8 constant DEFAULT_ORACLE_DECIMALS = 8;

  // sample users used across unit tests
  address constant alice = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
  address constant bob = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
  address constant carlos = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Constants {
  // ERC1967 slots
  bytes32 internal constant ERC1967_IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
  bytes32 internal constant ERC1967_ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  // addresses expected for BGD stkAave
  address constant SHORT_EXECUTOR = 0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;
  address constant STKAAVE_PROXY_ADMIN = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;

  // default admin role
  bytes32 public constant DEFAULT_ADMIN_ROLE = bytes32(0);

  // admin roles for GhoToken
  bytes32 public constant GHO_TOKEN_FACILITATOR_MANAGER_ROLE =
    keccak256('FACILITATOR_MANAGER_ROLE');
  bytes32 public constant GHO_TOKEN_BUCKET_MANAGER_ROLE = keccak256('BUCKET_MANAGER_ROLE');

  // admin role for GSM
  bytes32 public constant GSM_CONFIGURATOR_ROLE = keccak256('CONFIGURATOR_ROLE');
  bytes32 public constant GSM_TOKEN_RESCUER_ROLE = keccak256('TOKEN_RESCUER_ROLE');
  bytes32 public constant GSM_SWAP_FREEZER_ROLE = keccak256('SWAP_FREEZER_ROLE');
  bytes32 public constant GSM_LIQUIDATOR_ROLE = keccak256('LIQUIDATOR_ROLE');

  // signature typehash for GSM
  bytes32 public constant GSM_BUY_ASSET_WITH_SIG_TYPEHASH =
    keccak256(
      'BuyAssetWithSig(address originator,uint256 minAmount,address receiver,uint256 nonce,uint256 deadline)'
    );
  bytes32 public constant GSM_SELL_ASSET_WITH_SIG_TYPEHASH =
    keccak256(
      'SellAssetWithSig(address originator,uint256 maxAmount,address receiver,uint256 nonce,uint256 deadline)'
    );

  // signature typehash for GSM Converter
  bytes32 public constant GSM_CONVERTER_BUY_ASSET_WITH_SIG_TYPEHASH =
    keccak256(
      'BuyAssetWithSig(address originator,uint256 minAmount,address receiver,uint256 nonce,uint256 deadline)'
    );
  bytes32 public constant GSM_CONVERTER_SELL_ASSET_WITH_SIG_TYPEHASH =
    keccak256(
      'SellAssetWithSig(address originator,uint256 maxAmount,address receiver,uint256 nonce,uint256 deadline)'
    );

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
  uint128 constant DEFAULT_GSM_BUIDL_EXPOSURE = 100_000_000e6; // 6 decimals for BUIDL
  uint128 constant DEFAULT_GSM_USDC_AMOUNT = 100e6; // 6 decimals for USDC
  uint128 constant DEFAULT_GSM_BUIDL_AMOUNT = 100e6; // 6 decimals for BUIDL
  uint128 constant DEFAULT_GSM_GHO_AMOUNT = 100e18;

  // Gho Stewards
  uint32 constant GHO_BORROW_RATE_CHANGE_MAX = 0.05e4;
  uint256 constant GSM_FEE_RATE_CHANGE_MAX = 0.0050e4;
  uint32 constant GHO_BORROW_RATE_MAX = 0.25e4;
  uint256 constant MINIMUM_DELAY_V2 = 1 days;
  uint256 constant FIXED_RATE_STRATEGY_FACTORY_REVISION = 1;

  // sample users used across unit tests
  address constant ALICE = address(0x1111);
  address constant BOB = address(0x1112);
  address constant CHARLES = address(0x1113);

  address constant FAUCET = address(0x10001);
  address constant TREASURY = address(0x10002);
  address constant RISK_COUNCIL = address(0x10003);
}

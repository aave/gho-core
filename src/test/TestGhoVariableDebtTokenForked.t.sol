// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InitializableImmutableAdminUpgradeabilityProxy} from '@aave/core-v3/contracts/protocol/libraries/aave-upgradeability/InitializableImmutableAdminUpgradeabilityProxy.sol';
import './TestGhoBase.t.sol';

contract TestGhoVariableDebtTokenForked is TestGhoBase {
  IGhoToken gho = IGhoToken(0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f);
  address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address aave = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
  address stkAave = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;
  InitializableImmutableAdminUpgradeabilityProxy debtToken =
    InitializableImmutableAdminUpgradeabilityProxy(
      payable(0x786dBff3f1292ae8F92ea68Cf93c30b34B1ed04B)
    );
  IPool pool = IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
  address admin = 0x64b761D848206f447Fe2dd461b0c635Ec39EbB27;

  uint256 usdcSupplyAmount = 100_000e6;
  uint256 ghoBorrowAmount = 71_000e18;
  uint256 stkAaveAmount = 100_000e18;

  function setUp() public {
    vm.createSelectFork(vm.envString('ETH_RPC_URL'), 17987863);
  }

  function testBorrowAndRepayFullUnexpectedScaledBalance() public {
    uint256 timeSkip = 86545113;

    // Stake AAVE
    deal(aave, ALICE, stkAaveAmount);
    vm.startPrank(ALICE);
    IERC20(aave).approve(stkAave, stkAaveAmount);
    IStakedAaveV3(stkAave).stake(ALICE, stkAaveAmount);
    vm.stopPrank();

    // Supply USDC, borrow GHO
    deal(usdc, ALICE, usdcSupplyAmount);
    vm.startPrank(ALICE);
    IERC20(usdc).approve(address(pool), usdcSupplyAmount);
    pool.supply(usdc, usdcSupplyAmount, ALICE, 0);
    pool.borrow(address(gho), ghoBorrowAmount, 2, 0, ALICE);
    vm.stopPrank();

    vm.warp(block.timestamp + timeSkip);

    // Ensure Alice has the correct GHO balance
    uint256 allDebt = IERC20(address(debtToken)).balanceOf(ALICE);
    deal(address(gho), ALICE, allDebt);

    // Repay in full
    vm.startPrank(ALICE);
    gho.approve(address(pool), type(uint256).max);
    pool.repay(address(gho), type(uint256).max, 2, ALICE);
    vm.stopPrank();

    DataTypes.UserConfigurationMap memory userConfig = pool.getUserConfiguration(ALICE);
    bool isBorrowing = ((userConfig.data >> (20 << 1)) & 1 != 0);

    // Verify isBorrowing is false, but there is a non-zero scaledBalance
    assertEq(isBorrowing, false, 'Unexpected borrow state');
    assertEq(GhoAToken(address(debtToken)).scaledBalanceOf(ALICE), 1, 'Unexpected scaled balance');
  }

  function testBorrowAndRepayFullAmountUpgradeVerifyNoDust(uint256 timeSkip) public {
    timeSkip = bound(timeSkip, 1, 31_560_000);
    address newDebtToken = address(new GhoVariableDebtToken(pool));

    // Stake AAVE
    deal(aave, ALICE, stkAaveAmount);
    vm.startPrank(ALICE);
    IERC20(aave).approve(stkAave, stkAaveAmount);
    IStakedAaveV3(stkAave).stake(ALICE, stkAaveAmount);
    vm.stopPrank();

    // Supply USDC, borrow GHO
    deal(usdc, ALICE, usdcSupplyAmount);
    vm.startPrank(ALICE);
    IERC20(usdc).approve(address(pool), usdcSupplyAmount);
    pool.supply(usdc, usdcSupplyAmount, ALICE, 0);
    pool.borrow(address(gho), ghoBorrowAmount, 2, 0, ALICE);
    vm.stopPrank();

    // Upgrade GhoVariableDebtToken
    vm.prank(admin);
    debtToken.upgradeTo(newDebtToken);

    vm.warp(block.timestamp + timeSkip);

    // Ensure Alice has the correct GHO balance
    uint256 allDebt = IERC20(address(debtToken)).balanceOf(ALICE);
    deal(address(gho), ALICE, allDebt);

    // Repay in full
    vm.startPrank(ALICE);
    gho.approve(address(pool), type(uint256).max);
    pool.repay(address(gho), type(uint256).max, 2, ALICE);
    vm.stopPrank();

    DataTypes.UserConfigurationMap memory userConfig = pool.getUserConfiguration(ALICE);
    bool isBorrowing = ((userConfig.data >> (20 << 1)) & 1 != 0);

    // Ensure isBorrowing is false and the scaledBalance never exceeds zero
    assertEq(isBorrowing, false, 'Unexpected borrow state');
    assertEq(GhoAToken(address(debtToken)).scaledBalanceOf(ALICE), 0, 'Unexpected scaled balance');
  }
}

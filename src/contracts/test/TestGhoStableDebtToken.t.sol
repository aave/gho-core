// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import './TestGhoBase.t.sol';

contract TestGhoStableDebtToken is TestGhoBase {
  function testConstructor() public {
    GhoStableDebtToken debtToken = new GhoStableDebtToken(IPool(address(POOL)));
    assertEq(debtToken.name(), 'GHO_STABLE_DEBT_TOKEN_IMPL', 'Wrong default ERC20 name');
    assertEq(debtToken.symbol(), 'GHO_STABLE_DEBT_TOKEN_IMPL', 'Wrong default ERC20 symbol');
    assertEq(debtToken.decimals(), 0, 'Wrong default ERC20 decimals');
  }

  function testInitialize() public {
    GhoStableDebtToken debtToken = new GhoStableDebtToken(IPool(address(POOL)));
    string memory tokenName = 'GHO Stable Debt';
    string memory tokenSymbol = 'GhoStaDebt';
    bytes memory empty;
    debtToken.initialize(
      IPool(address(POOL)),
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      tokenName,
      tokenSymbol,
      empty
    );

    assertEq(debtToken.name(), tokenName, 'Wrong initialized name');
    assertEq(debtToken.symbol(), tokenSymbol, 'Wrong initialized symbol');
    assertEq(debtToken.decimals(), 18, 'Wrong ERC20 decimals');
  }

  function testInitializePoolRevert() public {
    string memory tokenName = 'GHO Stable Debt';
    string memory tokenSymbol = 'GhoStaDebt';
    bytes memory empty;

    GhoStableDebtToken debtToken = new GhoStableDebtToken(IPool(address(POOL)));
    vm.expectRevert(bytes(Errors.POOL_ADDRESSES_DO_NOT_MATCH));
    debtToken.initialize(
      IPool(address(0)),
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      tokenName,
      tokenSymbol,
      empty
    );
  }

  function testReInitRevert() public {
    string memory tokenName = 'GHO Stable Debt';
    string memory tokenSymbol = 'GhoStaDebt';
    bytes memory empty;

    vm.expectRevert(bytes('Contract instance has already been initialized'));
    GHO_STABLE_DEBT_TOKEN.initialize(
      IPool(address(POOL)),
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      tokenName,
      tokenSymbol,
      empty
    );
  }

  function testUnderlying() public {
    assertEq(
      GHO_STABLE_DEBT_TOKEN.UNDERLYING_ASSET_ADDRESS(),
      address(GHO_TOKEN),
      'Underlying should match token'
    );
  }

  function testTransferRevert() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_STABLE_DEBT_TOKEN.transfer(carlos, 1);
  }

  function testTransferFromRevert() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_STABLE_DEBT_TOKEN.transferFrom(alice, carlos, 1);
  }

  function testApproveRevert() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_STABLE_DEBT_TOKEN.approve(carlos, 1);
  }

  function testIncreaseAllowanceRevert() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_STABLE_DEBT_TOKEN.increaseAllowance(carlos, 1);
  }

  function testDecreaseAllowanceRevert() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_STABLE_DEBT_TOKEN.decreaseAllowance(carlos, 1);
  }

  function testAllowanceRevert() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_STABLE_DEBT_TOKEN.allowance(carlos, alice);
  }

  function testPrincipalBalanceOfZero() public {
    assertEq(GHO_STABLE_DEBT_TOKEN.principalBalanceOf(alice), 0, 'Unexpected principal balance');
    assertEq(GHO_STABLE_DEBT_TOKEN.principalBalanceOf(bob), 0, 'Unexpected principal balance');
    assertEq(GHO_STABLE_DEBT_TOKEN.principalBalanceOf(carlos), 0, 'Unexpected principal balance');
  }

  function testMintRevert() public {
    vm.prank(address(POOL));
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_STABLE_DEBT_TOKEN.mint(alice, alice, 0, 0);
  }

  function testMintByOther() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.CALLER_MUST_BE_POOL));
    GHO_STABLE_DEBT_TOKEN.mint(alice, alice, 0, 0);
  }

  function testBurnRevert() public {
    vm.prank(address(POOL));
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_STABLE_DEBT_TOKEN.burn(alice, 0);
  }

  function testBurnByOther() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.CALLER_MUST_BE_POOL));
    GHO_STABLE_DEBT_TOKEN.burn(alice, 0);
  }

  function testGetAverageStableRateZero() public {
    uint256 result = GHO_STABLE_DEBT_TOKEN.getAverageStableRate();
    assertEq(result, 0, 'Unexpected stable rate');
  }

  function testGetUserLastUpdatedZero() public {
    assertEq(GHO_STABLE_DEBT_TOKEN.getUserLastUpdated(alice), 0, 'Unexpected stable rate');
    assertEq(GHO_STABLE_DEBT_TOKEN.getUserLastUpdated(bob), 0, 'Unexpected stable rate');
    assertEq(GHO_STABLE_DEBT_TOKEN.getUserLastUpdated(carlos), 0, 'Unexpected stable rate');
  }

  function testGetUserStableRateZero() public {
    assertEq(GHO_STABLE_DEBT_TOKEN.getUserStableRate(alice), 0, 'Unexpected stable rate');
    assertEq(GHO_STABLE_DEBT_TOKEN.getUserStableRate(bob), 0, 'Unexpected stable rate');
    assertEq(GHO_STABLE_DEBT_TOKEN.getUserStableRate(carlos), 0, 'Unexpected stable rate');
  }

  function testGetUserBalanceZero() public {
    assertEq(GHO_STABLE_DEBT_TOKEN.balanceOf(alice), 0, 'Unexpected stable rate');
    assertEq(GHO_STABLE_DEBT_TOKEN.balanceOf(bob), 0, 'Unexpected stable rate');
    assertEq(GHO_STABLE_DEBT_TOKEN.balanceOf(carlos), 0, 'Unexpected stable rate');
  }

  function testGetSupplyDataZero() public {
    (
      uint256 totalSupply,
      uint256 calcTotalSupply,
      uint256 avgRate,
      uint40 timestamp
    ) = GHO_STABLE_DEBT_TOKEN.getSupplyData();
    assertEq(totalSupply, 0, 'Unexpected total supply');
    assertEq(calcTotalSupply, 0, 'Unexpected total supply');
    assertEq(avgRate, 0, 'Unexpected average rate');
    assertEq(timestamp, 0, 'Unexpected timestamp');
  }

  function testGetTotalSupplyAvgRateZero() public {
    (uint256 calcTotalSupply, uint256 avgRate) = GHO_STABLE_DEBT_TOKEN.getTotalSupplyAndAvgRate();
    assertEq(calcTotalSupply, 0, 'Unexpected total supply');
    assertEq(avgRate, 0, 'Unexpected average rate');
  }

  function testTotalSupplyZero() public {
    uint256 result = GHO_STABLE_DEBT_TOKEN.totalSupply();
    assertEq(result, 0, 'Unexpected total supply');
  }

  function testTotalSupplyLastUpdatedZero() public {
    uint40 result = GHO_STABLE_DEBT_TOKEN.getTotalSupplyLastUpdated();
    assertEq(result, 0, 'Unexpected timestamp');
  }
}

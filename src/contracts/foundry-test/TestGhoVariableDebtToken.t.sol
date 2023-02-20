// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import './TestEnv.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {DebtUtils} from './libraries/DebtUtils.sol';

contract TestGhoVariableDebtToken is Test, TestEnv {
  address public alice;
  address public bob;
  address public carlos;
  uint256 borrowAmount = 200e18;

  function setUp() public {
    alice = users[0];
    bob = users[1];
    carlos = users[2];
  }

  function testConstructor() public {
    GhoVariableDebtToken debtToken = new GhoVariableDebtToken(IPool(address(POOL)));
    assertEq(debtToken.name(), 'GHO_VARIABLE_DEBT_TOKEN_IMPL', 'Wrong default ERC20 name');
    assertEq(debtToken.symbol(), 'GHO_VARIABLE_DEBT_TOKEN_IMPL', 'Wrong default ERC20 symbol');
    assertEq(debtToken.decimals(), 0, 'Wrong default ERC20 decimals');
  }

  function testInitialize() public {
    GhoVariableDebtToken debtToken = new GhoVariableDebtToken(IPool(address(POOL)));
    string memory tokenName = 'GHO Variable Debt';
    string memory tokenSymbol = 'GhoVarDebt';
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

  function testReInitRevert() public {
    string memory tokenName = 'GHO Variable Debt';
    string memory tokenSymbol = 'GhoVarDebt';
    bytes memory empty;

    vm.expectRevert(bytes('Contract instance has already been initialized'));
    GHO_DEBT_TOKEN.initialize(
      IPool(address(POOL)),
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      tokenName,
      tokenSymbol,
      empty
    );
  }

  function testBorrow(uint256 fuzzAmount) public {
    vm.assume(fuzzAmount < 100000000000000000000000001);
    vm.assume(fuzzAmount > 0);
    vm.startPrank(alice);

    vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
    emit Transfer(address(0), alice, fuzzAmount);
    vm.expectEmit(true, true, true, true, address(GHO_DEBT_TOKEN));
    emit Mint(alice, alice, fuzzAmount, 0, 1e27);

    // Action
    POOL.borrow(address(GHO_TOKEN), fuzzAmount, 2, 0, alice);

    assertEq(GHO_TOKEN.balanceOf(alice), fuzzAmount, 'Gho amount doest not match borrow');
    assertEq(GHO_TOKEN.totalSupply(), fuzzAmount, 'Gho total supply does not match borrow');
    assertEq(
      GHO_DEBT_TOKEN.scaledBalanceOf(alice),
      fuzzAmount,
      'Gho debt token does not match borrow'
    );
    assertEq(
      GHO_DEBT_TOKEN.getBalanceFromInterest(alice),
      0,
      'Accumulated interest should be zero'
    );
  }

  function testPartialRepay() public {
    uint256 partialRepayAmount = 50e18;

    vm.startPrank(alice);

    // Perform borrow
    POOL.borrow(address(GHO_TOKEN), borrowAmount, 2, 0, alice);
    uint256 ghoTotalSupply = GHO_TOKEN.totalSupply();

    // Perform approve and repay
    GHO_TOKEN.approve(address(POOL), partialRepayAmount);

    POOL.repay(address(GHO_TOKEN), partialRepayAmount, 2, alice);

    assertEq(
      GHO_TOKEN.balanceOf(alice),
      borrowAmount - partialRepayAmount,
      'Alice GHO balance should have decreased the repay amount'
    );
    assertEq(
      GHO_TOKEN.totalSupply(),
      ghoTotalSupply - partialRepayAmount,
      'GHO Total Supply should have decreased the repay amount'
    );
    assertEq(
      GHO_DEBT_TOKEN.getBalanceFromInterest(alice),
      0,
      'Accumulated interest should be zero'
    );
  }

  function testFullRepay() public {
    vm.prank(alice);

    // Perform borrow
    POOL.borrow(address(GHO_TOKEN), borrowAmount, 2, 0, alice);

    vm.warp(block.timestamp + 2628000);

    uint256 allDebt = GHO_DEBT_TOKEN.balanceOf(alice);

    ghoFaucet(alice, 1e18);

    uint256 balanceBeforeRepay = GHO_TOKEN.balanceOf(alice);
    uint256 ghoTotalSupply = GHO_TOKEN.totalSupply();
    uint256 interest = allDebt - borrowAmount;

    (uint256 computedInterest, , ) = DebtUtils.computeDebt(
      1e27,
      POOL.getReserveNormalizedVariableDebt(address(GHO_TOKEN)),
      GHO_DEBT_TOKEN.scaledBalanceOf(alice),
      0,
      0
    );

    // Perform approve and repay
    vm.startPrank(alice);
    GHO_TOKEN.approve(address(POOL), type(uint256).max);
    POOL.repay(address(GHO_TOKEN), allDebt, 2, alice);

    assertEq(
      GHO_TOKEN.balanceOf(alice),
      balanceBeforeRepay - allDebt,
      'Alice GHO balance should have decreasaed the debt amount'
    );
    assertEq(GHO_DEBT_TOKEN.balanceOf(alice), 0, 'Alice Variable Debt GHO balance should be zero');
    assertEq(
      GHO_TOKEN.totalSupply(),
      ghoTotalSupply - allDebt + interest,
      'GHO Total Supply should have decreased the repay amount'
    );
    assertEq(
      GHO_DEBT_TOKEN.getBalanceFromInterest(alice),
      0,
      'Accumulated interest should be reset to zero'
    );
    assertEq(interest, computedInterest, 'Computed interest should match interest');
  }

  function testTransferRevert() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_DEBT_TOKEN.transfer(carlos, 1);
  }

  function testTransferFromRevert() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_DEBT_TOKEN.transferFrom(alice, carlos, 1);
  }

  function testApproveRevert() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_DEBT_TOKEN.approve(carlos, 1);
  }

  function testIncreaseAllowanceRevert() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_DEBT_TOKEN.increaseAllowance(carlos, 1);
  }

  function testDecreaseAllowanceRevert() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_DEBT_TOKEN.decreaseAllowance(carlos, 1);
  }

  function testAllowanceRevert() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    GHO_DEBT_TOKEN.allowance(carlos, alice);
  }

  function testUpdateDiscountByOther() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes('CALLER_NOT_DISCOUNT_TOKEN'));
    GHO_DEBT_TOKEN.updateDiscountDistribution(alice, alice, 0, 0, 0);
  }

  function testDecreaseBalanceByOther() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes('CALLER_NOT_A_TOKEN'));
    GHO_DEBT_TOKEN.decreaseBalanceFromInterest(alice, 1);
  }

  function testMintByOther() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.CALLER_MUST_BE_POOL));
    GHO_DEBT_TOKEN.mint(alice, alice, 0, 0);
  }

  function testBurnByOther() public {
    vm.startPrank(alice);

    vm.expectRevert(bytes(Errors.CALLER_MUST_BE_POOL));
    GHO_DEBT_TOKEN.burn(alice, 0, 0);
  }

  function testSetATokenByOther() public {
    GhoVariableDebtToken debtToken = new GhoVariableDebtToken(IPool(address(POOL)));

    vm.startPrank(alice);
    ACL_MANAGER.setState(false);

    vm.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));
    debtToken.setAToken(alice);
  }

  function testUpdateAToken() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes('ATOKEN_ALREADY_SET'));
    GHO_DEBT_TOKEN.setAToken(alice);
  }

  function testZeroAToken() public {
    GhoVariableDebtToken debtToken = new GhoVariableDebtToken(IPool(address(POOL)));

    vm.startPrank(alice);
    vm.expectRevert(bytes('ZERO_ADDRESS_NOT_VALID'));
    debtToken.setAToken(address(0));
  }

  function testUpdateDiscountRateStrategyByOther() public {
    vm.startPrank(alice);
    ACL_MANAGER.setState(false);

    vm.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));
    GHO_DEBT_TOKEN.updateDiscountRateStrategy(alice);
  }

  function testUpdateDiscountTokenByOther() public {
    vm.startPrank(alice);
    ACL_MANAGER.setState(false);

    vm.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));
    GHO_DEBT_TOKEN.updateDiscountToken(alice);
  }

  function testUpdateDiscountTokenToZero() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes('ZERO_ADDR'));
    GHO_DEBT_TOKEN.updateDiscountToken(address(0));
  }

  function testUpdateDiscountStrategy() public {
    vm.startPrank(alice);
    GHO_DEBT_TOKEN.updateDiscountRateStrategy(carlos);
    assertEq(
      GHO_DEBT_TOKEN.getDiscountRateStrategy(),
      carlos,
      'Discount Rate Strategy should be updated'
    );
  }

  function testUpdateDiscountToken() public {
    vm.startPrank(alice);
    GHO_DEBT_TOKEN.updateDiscountToken(carlos);
    assertEq(GHO_DEBT_TOKEN.getDiscountToken(), carlos, 'Discount token should be updated');
  }
}

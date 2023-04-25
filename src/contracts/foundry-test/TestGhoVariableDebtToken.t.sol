// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import './TestEnv.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {DebtUtils} from './libraries/DebtUtils.sol';
import {GhoActions} from './libraries/GhoActions.sol';

contract TestGhoVariableDebtToken is Test, GhoActions {
  address public alice;
  address public bob;
  address public carlos;
  uint256 borrowAmount = 200e18;

  event ATokenSet(address indexed);

  function setUp() public {
    alice = users[0];
    bob = users[1];
    carlos = users[2];
    mintAndStakeDiscountToken(bob, 10_000e18);
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

  function testInitializePoolRevert() public {
    string memory tokenName = 'GHO Variable Debt';
    string memory tokenSymbol = 'GhoVarDebt';
    bytes memory empty;

    GhoVariableDebtToken debtToken = new GhoVariableDebtToken(IPool(address(POOL)));
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

  function testBorrowFixed() public {
    borrowAction(alice, borrowAmount);
  }

  function testBorrowOnBehalf() public {
    vm.prank(bob);
    GHO_DEBT_TOKEN.approveDelegation(alice, borrowAmount);

    borrowActionOnBehalf(alice, bob, borrowAmount);
  }

  function testBorrowFuzz(uint256 fuzzAmount) public {
    vm.assume(fuzzAmount < 100000000000000000000000001);
    vm.assume(fuzzAmount > 0);
    borrowAction(alice, fuzzAmount);
    assertEq(
      GHO_DEBT_TOKEN.getBalanceFromInterest(alice),
      0,
      'Accumulated interest should be zero'
    );
  }

  function testBorrowFixedWithDiscount() public {
    borrowAction(bob, borrowAmount);
  }

  function testMultipleBorrowFixedWithDiscount() public {
    borrowAction(bob, borrowAmount);
    vm.warp(block.timestamp + 100000000);
    borrowAction(bob, 1e16);
  }

  function testBorrowMultiple() public {
    for (uint x; x < 100; ++x) {
      borrowAction(alice, borrowAmount);
      vm.warp(block.timestamp + 2628000);
    }
  }

  function testBorrowMultipleWithDiscount() public {
    for (uint x; x < 100; ++x) {
      borrowAction(bob, borrowAmount);
      vm.warp(block.timestamp + 2628000);
    }
  }

  function testBorrowMultipleFuzz(uint256 fuzzAmount) public {
    vm.assume(fuzzAmount < 1000000000000000000000000);
    vm.assume(fuzzAmount > 0);

    for (uint x; x < 10; ++x) {
      borrowAction(alice, fuzzAmount);
      vm.warp(block.timestamp + 2628000);
    }
  }

  function testPartialMinorRepay() public {
    uint256 partialRepayAmount = 1e7;

    // Perform borrow
    borrowAction(alice, borrowAmount);

    vm.warp(block.timestamp + 2628000);

    // Perform repayment
    repayAction(alice, partialRepayAmount);
  }

  function testPartialRepay() public {
    uint256 partialRepayAmount = 50e18;

    // Perform borrow
    borrowAction(alice, borrowAmount);

    vm.warp(block.timestamp + 2628000);

    // Perform repayment
    repayAction(alice, partialRepayAmount);
  }

  function testPartialRepayDiscount() public {
    uint256 partialRepayAmount = 50e18;

    // Perform borrow
    borrowAction(alice, borrowAmount);

    vm.warp(block.timestamp + 2628000);

    repayAction(alice, partialRepayAmount);

    mintAndStakeDiscountToken(alice, 10_000e18);
    vm.warp(block.timestamp + 2628000);

    repayAction(alice, partialRepayAmount);
  }

  function testFullRepay() public {
    vm.prank(alice);

    // Perform borrow
    borrowAction(alice, borrowAmount);

    vm.warp(block.timestamp + 2628000);

    uint256 allDebt = GHO_DEBT_TOKEN.balanceOf(alice);

    ghoFaucet(alice, 1e18);

    repayAction(alice, allDebt);
  }

  function testMultipleMinorRepay() public {
    uint256 partialRepayAmount = 1e7;

    // Perform borrow
    borrowAction(alice, borrowAmount);

    vm.warp(block.timestamp + 2628000);

    for (uint x; x < 100; ++x) {
      repayAction(alice, partialRepayAmount);
      vm.warp(block.timestamp + 2628000);
    }
  }

  function testMultipleRepay() public {
    uint256 partialRepayAmount = 50e18;

    // Perform borrow
    borrowAction(alice, borrowAmount);

    vm.warp(block.timestamp + 2628000);

    for (uint x; x < 4; ++x) {
      repayAction(alice, partialRepayAmount);
      vm.warp(block.timestamp + 2628000);
    }
  }

  function testDiscountRebalance() public {
    mintAndStakeDiscountToken(alice, 10e18);
    borrowAction(alice, 1000e18);
    vm.warp(block.timestamp + 10000000000);

    rebalanceDiscountAction(alice);
  }

  function testUnderlying() public {
    assertEq(
      GHO_DEBT_TOKEN.UNDERLYING_ASSET_ADDRESS(),
      address(GHO_TOKEN),
      'Underlying should match token'
    );
  }

  function testGetAToken() public {
    assertEq(
      GHO_DEBT_TOKEN.getAToken(),
      address(GHO_ATOKEN),
      'AToken getter should match Gho AToken'
    );
  }

  function testBalanceOfSameIndex() public {
    borrowAction(alice, borrowAmount);
    uint256 balanceOne = GHO_DEBT_TOKEN.balanceOf(alice);
    uint256 balanceTwo = GHO_DEBT_TOKEN.balanceOf(alice);
    assertEq(balanceOne, balanceTwo, 'Balance should be equal if index doesnt increase');
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

  function testUpdateDiscount() public {
    borrowAction(alice, borrowAmount);
    borrowAction(bob, borrowAmount);
    vm.warp(block.timestamp + 1000);

    vm.prank(address(STK_TOKEN));
    GHO_DEBT_TOKEN.updateDiscountDistribution(alice, bob, 0, 0, 0);
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

  function testSetAToken() public {
    GhoVariableDebtToken debtToken = new GhoVariableDebtToken(IPool(address(POOL)));

    vm.expectEmit(true, true, true, true, address(debtToken));
    emit ATokenSet(address(GHO_ATOKEN));

    debtToken.setAToken(address(GHO_ATOKEN));
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
    vm.expectRevert(bytes('ZERO_ADDRESS_NOT_VALID'));
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

  function testUpdateDiscountTokenWithBorrow() public {
    borrowAction(bob, borrowAmount);
    vm.warp(block.timestamp + 10000);

    vm.startPrank(alice);
    GHO_DEBT_TOKEN.updateDiscountToken(bob);
    assertEq(GHO_DEBT_TOKEN.getDiscountToken(), bob, 'Discount token should be updated');
  }
}

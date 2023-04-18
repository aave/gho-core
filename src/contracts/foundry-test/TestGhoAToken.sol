// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import './TestEnv.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {DebtUtils} from './libraries/DebtUtils.sol';
import {GhoActions} from './libraries/GhoActions.sol';

contract TestGhoAToken is Test, GhoActions {
  address public alice;
  address public bob;
  address public carlos;
  uint256 borrowAmount = 200e18;

  event VariableDebtTokenSet(address indexed variableDebtToken);
  event FeesDistributedToTreasury(
    address indexed ghoTreasury,
    address indexed asset,
    uint256 amount
  );
  event GhoTreasuryUpdated(address indexed oldGhoTreasury, address indexed newGhoTreasury);

  function setUp() public {
    alice = users[0];
    bob = users[1];
    carlos = users[2];
    mintAndStakeDiscountToken(bob, 10_000e18);
  }

  function testConstructor() public {
    GhoAToken aToken = new GhoAToken(IPool(address(POOL)));
    assertEq(aToken.name(), 'GHO_ATOKEN_IMPL', 'Wrong default ERC20 name');
    assertEq(aToken.symbol(), 'GHO_ATOKEN_IMPL', 'Wrong default ERC20 symbol');
    assertEq(aToken.decimals(), 0, 'Wrong default ERC20 decimals');
  }

  function testInitialize() public {
    GhoAToken aToken = new GhoAToken(IPool(address(POOL)));
    string memory tokenName = 'GHO AToken';
    string memory tokenSymbol = 'aGHO';
    bytes memory empty;
    aToken.initialize(
      IPool(address(POOL)),
      treasury,
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      tokenName,
      tokenSymbol,
      empty
    );

    assertEq(aToken.name(), tokenName, 'Wrong initialized name');
    assertEq(aToken.symbol(), tokenSymbol, 'Wrong initialized symbol');
    assertEq(aToken.decimals(), 18, 'Wrong ERC20 decimals');
  }

  function testInitializePoolRevert() public {
    string memory tokenName = 'GHO AToken';
    string memory tokenSymbol = 'aGHO';
    bytes memory empty;

    GhoAToken aToken = new GhoAToken(IPool(address(POOL)));
    vm.expectRevert(bytes(Errors.POOL_ADDRESSES_DO_NOT_MATCH));
    aToken.initialize(
      IPool(address(0)),
      treasury,
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      tokenName,
      tokenSymbol,
      empty
    );
  }

  function testReInitRevert() public {
    string memory tokenName = 'GHO AToken';
    string memory tokenSymbol = 'aGHO';
    bytes memory empty;

    vm.expectRevert(bytes('Contract instance has already been initialized'));
    GHO_ATOKEN.initialize(
      IPool(address(POOL)),
      treasury,
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
      GHO_ATOKEN.UNDERLYING_ASSET_ADDRESS(),
      address(GHO_TOKEN),
      'Underlying should match token'
    );
  }

  function testGetVariableDebtToken() public {
    assertEq(
      GHO_ATOKEN.getVariableDebtToken(),
      address(GHO_DEBT_TOKEN),
      'Variable debt token getter should match Gho Variable Debt Token'
    );
  }

  function testMintByOther() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes(Errors.CALLER_MUST_BE_POOL));
    GHO_ATOKEN.mint(alice, alice, 0, 0);
  }

  function testBurnByOther() public {
    vm.startPrank(alice);

    vm.expectRevert(bytes(Errors.CALLER_MUST_BE_POOL));
    GHO_ATOKEN.burn(alice, alice, 0, 0);
  }

  function testSetVariableDebtTokenByOther() public {
    GhoAToken aToken = new GhoAToken(IPool(address(POOL)));

    vm.startPrank(alice);
    ACL_MANAGER.setState(false);

    vm.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));
    aToken.setVariableDebtToken(alice);
  }

  function testSetVariableDebtToken() public {
    GhoAToken aToken = new GhoAToken(IPool(address(POOL)));

    vm.expectEmit(true, true, true, true, address(aToken));
    emit VariableDebtTokenSet(address(GHO_DEBT_TOKEN));

    aToken.setVariableDebtToken(address(GHO_DEBT_TOKEN));
  }

  function testUpdateVariableDebtToken() public {
    vm.startPrank(alice);
    vm.expectRevert(bytes('VARIABLE_DEBT_TOKEN_ALREADY_SET'));
    GHO_ATOKEN.setVariableDebtToken(alice);
  }

  function testZeroVariableDebtToken() public {
    GhoAToken aToken = new GhoAToken(IPool(address(POOL)));

    vm.startPrank(alice);
    vm.expectRevert(bytes('ZERO_ADDRESS_NOT_VALID'));
    aToken.setVariableDebtToken(address(0));
  }

  function testMintRevert() public {
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    vm.prank(address(POOL));
    GHO_ATOKEN.mint(carlos, carlos, 1, 1);
  }

  function testPermitRevert() public {
    bytes32 empty;

    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    vm.prank(address(POOL));
    GHO_ATOKEN.permit(carlos, carlos, 1, 1, 1, empty, empty);
  }

  function testBurnRevert() public {
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    vm.prank(address(POOL));
    GHO_ATOKEN.burn(carlos, carlos, 1, 1);
  }

  function testMintToTreasuryRevert() public {
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    vm.prank(address(POOL));
    GHO_ATOKEN.mintToTreasury(1, 1);
  }

  function testTransferOnLiquidationRevert() public {
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    vm.prank(address(POOL));
    GHO_ATOKEN.transferOnLiquidation(carlos, carlos, 1);
  }

  function testStandardTransferRevert() public {
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    vm.prank(carlos);
    GHO_ATOKEN.transfer(alice, 0);
  }

  function testBalanceOfAlwaysZero() public {
    uint256 balance = GHO_ATOKEN.balanceOf(carlos);
    assertEq(balance, 0, 'AToken balance should always be zero');
  }

  function testTotalSupplyAlwaysZero() public {
    uint256 supply = GHO_ATOKEN.totalSupply();
    assertEq(supply, 0, 'AToken total supply should always be zero');
  }

  function testReserveTreasuryAddress() public {
    assertEq(
      GHO_ATOKEN.RESERVE_TREASURY_ADDRESS(),
      treasury,
      'AToken treasury address should match the initalized address'
    );
  }

  function testDistributeFees() public {
    borrowAction(carlos, 1000e18);
    vm.warp(block.timestamp + 640000);

    ghoFaucet(carlos, 5e18);

    repayAction(carlos, GHO_DEBT_TOKEN.balanceOf(carlos));

    vm.expectEmit(true, true, true, true, address(GHO_ATOKEN));
    emit FeesDistributedToTreasury(
      treasury,
      address(GHO_TOKEN),
      GHO_TOKEN.balanceOf(address(GHO_ATOKEN))
    );
    GHO_ATOKEN.distributeFeesToTreasury();
  }

  function testRescueToken() public {
    vm.prank(faucet);
    AAVE_TOKEN.mint(address(GHO_ATOKEN), 1);

    GHO_ATOKEN.rescueTokens(address(AAVE_TOKEN), carlos, 1);

    assertEq(AAVE_TOKEN.balanceOf(carlos), 1, 'Token rescue should transfer 1 wei');
  }

  function testRescueTokenRevertIfUnderlying() public {
    vm.expectRevert(bytes(Errors.UNDERLYING_CANNOT_BE_RESCUED));
    vm.prank(faucet);
    GHO_ATOKEN.rescueTokens(address(GHO_TOKEN), carlos, 1);
  }

  function testUpdateGhoTreasuryRevertIfZero() public {
    vm.expectRevert(bytes('ZERO_ADDRESS_NOT_VALID'));
    GHO_ATOKEN.updateGhoTreasury(address(0));
  }

  function testUpdateGhoTreasury() public {
    vm.expectEmit(true, true, true, true, address(GHO_ATOKEN));
    emit GhoTreasuryUpdated(treasury, alice);
    GHO_ATOKEN.updateGhoTreasury(alice);

    assertEq(GHO_ATOKEN.getGhoTreasury(), alice);
  }

  function testUpdateGhoTreasuryRevertByOther() public {
    ACL_MANAGER.setState(false);

    vm.prank(alice);

    vm.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));
    GHO_ATOKEN.updateGhoTreasury(alice);
  }
}

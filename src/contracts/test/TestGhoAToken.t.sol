// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import './TestGhoBase.t.sol';

contract TestGhoAToken is TestGhoBase {
  function testConstructor() public {
    GhoAToken aToken = new GhoAToken(IPool(address(POOL)));
    assertEq(aToken.name(), 'GHO_ATOKEN_IMPL', 'Wrong default ERC20 name');
    assertEq(aToken.symbol(), 'GHO_ATOKEN_IMPL', 'Wrong default ERC20 symbol');
    assertEq(aToken.decimals(), 0, 'Wrong default ERC20 decimals');
  }

  function testInitialize() public {
    GhoAToken aToken = new GhoAToken(IPool(address(POOL)));
    string memory tokenName = 'Aave GHO';
    string memory tokenSymbol = 'aGHO';
    bytes memory empty;
    aToken.initialize(
      IPool(address(POOL)),
      TREASURY,
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
    string memory tokenName = 'Aave GHO';
    string memory tokenSymbol = 'aGHO';
    bytes memory empty;

    GhoAToken aToken = new GhoAToken(IPool(address(POOL)));
    vm.expectRevert(bytes(Errors.POOL_ADDRESSES_DO_NOT_MATCH));
    aToken.initialize(
      IPool(address(0)),
      TREASURY,
      address(GHO_TOKEN),
      IAaveIncentivesController(address(0)),
      18,
      tokenName,
      tokenSymbol,
      empty
    );
  }

  function testReInitRevert() public {
    string memory tokenName = 'Aave GHO';
    string memory tokenSymbol = 'aGHO';
    bytes memory empty;

    vm.expectRevert(bytes('Contract instance has already been initialized'));
    GHO_ATOKEN.initialize(
      IPool(address(POOL)),
      TREASURY,
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

  function testUnauthorizedMint() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes(Errors.CALLER_MUST_BE_POOL));
    GHO_ATOKEN.mint(ALICE, ALICE, 0, 0);
  }

  function testUnauthorizedBurn() public {
    vm.startPrank(ALICE);

    vm.expectRevert(bytes(Errors.CALLER_MUST_BE_POOL));
    GHO_ATOKEN.burn(ALICE, ALICE, 0, 0);
  }

  function testUnauthorizedSetVariableDebtToken() public {
    GhoAToken aToken = new GhoAToken(IPool(address(POOL)));

    vm.startPrank(ALICE);
    ACL_MANAGER.setState(false);

    vm.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));
    aToken.setVariableDebtToken(ALICE);
  }

  function testSetVariableDebtToken() public {
    GhoAToken aToken = new GhoAToken(IPool(address(POOL)));

    vm.expectEmit(true, true, true, true, address(aToken));
    emit VariableDebtTokenSet(address(GHO_DEBT_TOKEN));

    aToken.setVariableDebtToken(address(GHO_DEBT_TOKEN));
  }

  function testUpdateVariableDebtToken() public {
    vm.startPrank(ALICE);
    vm.expectRevert(bytes('VARIABLE_DEBT_TOKEN_ALREADY_SET'));
    GHO_ATOKEN.setVariableDebtToken(ALICE);
  }

  function testZeroVariableDebtToken() public {
    GhoAToken aToken = new GhoAToken(IPool(address(POOL)));

    vm.startPrank(ALICE);
    vm.expectRevert(bytes('ZERO_ADDRESS_NOT_VALID'));
    aToken.setVariableDebtToken(address(0));
  }

  function testMintRevert() public {
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    vm.prank(address(POOL));
    GHO_ATOKEN.mint(CHARLES, CHARLES, 1, 1);
  }

  function testPermitRevert() public {
    bytes32 empty;

    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    vm.prank(address(POOL));
    GHO_ATOKEN.permit(CHARLES, CHARLES, 1, 1, 1, empty, empty);
  }

  function testBurnRevert() public {
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    vm.prank(address(POOL));
    GHO_ATOKEN.burn(CHARLES, CHARLES, 1, 1);
  }

  function testMintToTreasuryRevert() public {
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    vm.prank(address(POOL));
    GHO_ATOKEN.mintToTreasury(1, 1);
  }

  function testTransferOnLiquidationRevert() public {
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    vm.prank(address(POOL));
    GHO_ATOKEN.transferOnLiquidation(CHARLES, CHARLES, 1);
  }

  function testStandardTransferRevert() public {
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    vm.prank(CHARLES);
    GHO_ATOKEN.transfer(ALICE, 0);
  }

  function testBalanceOfAlwaysZero() public {
    uint256 balance = GHO_ATOKEN.balanceOf(CHARLES);
    assertEq(balance, 0, 'AToken balance should always be zero');
  }

  function testTotalSupplyAlwaysZero() public {
    uint256 supply = GHO_ATOKEN.totalSupply();
    assertEq(supply, 0, 'AToken total supply should always be zero');
  }

  function testReserveTreasuryAddress() public {
    assertEq(
      GHO_ATOKEN.RESERVE_TREASURY_ADDRESS(),
      TREASURY,
      'AToken treasury address should match the initalized address'
    );
  }

  function testDistributeFees() public {
    borrowAction(CHARLES, 1000e18);
    vm.warp(block.timestamp + 640000);

    ghoFaucet(CHARLES, 5e18);

    repayAction(CHARLES, GHO_DEBT_TOKEN.balanceOf(CHARLES));

    vm.expectEmit(true, true, true, true, address(GHO_ATOKEN));
    emit FeesDistributedToTreasury(
      TREASURY,
      address(GHO_TOKEN),
      GHO_TOKEN.balanceOf(address(GHO_ATOKEN))
    );
    GHO_ATOKEN.distributeFeesToTreasury();
  }

  function testRescueToken() public {
    vm.prank(FAUCET);
    AAVE_TOKEN.mint(address(GHO_ATOKEN), 1);

    GHO_ATOKEN.rescueTokens(address(AAVE_TOKEN), CHARLES, 1);

    assertEq(AAVE_TOKEN.balanceOf(CHARLES), 1, 'Token rescue should transfer 1 wei');
  }

  function testRescueTokenRevertIfUnderlying() public {
    vm.expectRevert(bytes(Errors.UNDERLYING_CANNOT_BE_RESCUED));
    vm.prank(FAUCET);
    GHO_ATOKEN.rescueTokens(address(GHO_TOKEN), CHARLES, 1);
  }

  function testUpdateGhoTreasuryRevertIfZero() public {
    vm.expectRevert(bytes('ZERO_ADDRESS_NOT_VALID'));
    GHO_ATOKEN.updateGhoTreasury(address(0));
  }

  function testUpdateGhoTreasury() public {
    vm.expectEmit(true, true, true, true, address(GHO_ATOKEN));
    emit GhoTreasuryUpdated(TREASURY, ALICE);
    GHO_ATOKEN.updateGhoTreasury(ALICE);

    assertEq(GHO_ATOKEN.getGhoTreasury(), ALICE);
  }

  function testUnauthorizedUpdateGhoTreasuryRevert() public {
    ACL_MANAGER.setState(false);

    vm.prank(ALICE);

    vm.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));
    GHO_ATOKEN.updateGhoTreasury(ALICE);
  }

  function testDomainSeparator() public {
    bytes32 EIP712_DOMAIN = keccak256(
      'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
    );
    bytes memory EIP712_REVISION = bytes('1');
    bytes32 expected = keccak256(
      abi.encode(
        EIP712_DOMAIN,
        keccak256(bytes(GHO_ATOKEN.name())),
        keccak256(EIP712_REVISION),
        block.chainid,
        address(GHO_ATOKEN)
      )
    );
    bytes32 result = GHO_ATOKEN.DOMAIN_SEPARATOR();
    assertEq(result, expected, 'Unexpected domain separator');
  }

  function testNonces() public {
    assertEq(GHO_ATOKEN.nonces(ALICE), 0, 'Unexpected non-zero nonce');
    assertEq(GHO_ATOKEN.nonces(BOB), 0, 'Unexpected non-zero nonce');
    assertEq(GHO_ATOKEN.nonces(CHARLES), 0, 'Unexpected non-zero nonce');
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

contract TestGsmToken is TestGhoBase {
  function testConstructor() public {
    vm.expectEmit(true, true, true, true);
    emit RoleGranted(GHO_GSM_TOKEN.DEFAULT_ADMIN_ROLE(), address(this), address(this));
    GsmToken gsmToken = new GsmToken(address(this), 'Test', 'test', 6, address(USDC_TOKEN));
    assertEq(gsmToken.name(), 'Test', 'Unexpected token name');
    assertEq(gsmToken.symbol(), 'test', 'Unexpected token symbol');
    assertEq(gsmToken.decimals(), 6, 'Unexpected token decimals');
  }

  function testGetUnderlyingAsset() public {
    assertEq(GHO_GSM_TOKEN.UNDERLYING_ASSET(), address(USDC_TOKEN), 'Unexpected underlying asset');
  }

  function testMint() public {
    vm.prank(address(GHO_GSM));
    vm.expectEmit(true, true, false, true, address(GHO_GSM_TOKEN));
    emit Transfer(address(0), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);
  }

  function testRevertMintNotAuthorize() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_TOKEN_MINTER_ROLE, ALICE));
    vm.prank(ALICE);
    GHO_GSM_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);
  }

  function testBurn() public {
    vm.startPrank(address(GHO_GSM));
    vm.expectEmit(true, true, false, true, address(GHO_GSM_TOKEN));
    emit Transfer(address(0), address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_TOKEN.mint(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);

    vm.expectEmit(true, true, false, true, address(GHO_GSM_TOKEN));
    emit Transfer(address(GHO_GSM), address(0), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_TOKEN.burn(DEFAULT_GSM_USDC_AMOUNT);
    vm.stopPrank();
  }

  function testRevertBurnNotAuthorized() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_TOKEN_MINTER_ROLE, ALICE));
    vm.prank(ALICE);
    GHO_GSM_TOKEN.burn(DEFAULT_GSM_USDC_AMOUNT);
  }
}

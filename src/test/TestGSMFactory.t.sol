// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGSMFactory is TestGhoBase {
  bytes32 _salt;
  GsmFactory _factory;

  function setUp() public {
    uint256 forkId = vm.createFork(vm.envString('ETH_RPC_URL'));
    vm.selectFork(forkId);
    setupGho();
    _factory = new GsmFactory();
    _salt = bytes32(0);
  }

  function testDeployGsm() public {
    Gsm gsm = Gsm(_factory.deployGsm(_salt, address(GHO_TOKEN), address(USDC_TOKEN)));
    assertEq(gsm.GHO_TOKEN(), address(GHO_TOKEN), 'Unexpected GHO token address');
    assertEq(gsm.UNDERLYING_ASSET(), address(USDC_TOKEN), 'Unexpected underlying asset address');
  }

  function testRevertDeployGsmNotAuth() public {
    vm.prank(ALICE);
    vm.expectRevert('Ownable: caller is not the owner');
    _factory.deployGsm(_salt, address(GHO_TOKEN), address(USDC_TOKEN));
  }

  function testRevertDeployGsmSameSalt() public {
    _factory.deployGsm(_salt, address(GHO_TOKEN), address(USDC_TOKEN));

    vm.expectRevert('CONTRACT_ALREADY_DEPLOYED');
    _factory.deployGsm(_salt, address(GHO_TOKEN), address(USDC_TOKEN));
  }

  function testDeployGsmToken() public {
    vm.expectEmit(true, true, true, true);
    emit RoleGranted(GHO_GSM_TOKEN.DEFAULT_ADMIN_ROLE(), address(this), address(_factory));
    GsmToken gsmToken = GsmToken(
      _factory.deployGsmToken(_salt, address(this), 'Test', 'test', 6, address(USDC_TOKEN))
    );
    assertEq(gsmToken.name(), 'Test', 'Unexpected token name');
    assertEq(gsmToken.symbol(), 'test', 'Unexpected token symbol');
    assertEq(gsmToken.decimals(), 6, 'Unexpected token decimals');
  }

  function testRevertDeployGsmTokenNotAuth() public {
    vm.prank(ALICE);
    vm.expectRevert('Ownable: caller is not the owner');
    _factory.deployGsmToken(_salt, address(this), 'Test', 'test', 6, address(USDC_TOKEN));
  }

  function testRevertDeployGsmTokenSameSalt() public {
    _factory.deployGsmToken(_salt, address(this), 'Test', 'test', 6, address(USDC_TOKEN));

    vm.expectRevert('CONTRACT_ALREADY_DEPLOYED');
    _factory.deployGsmToken(_salt, address(this), 'Test', 'test', 6, address(USDC_TOKEN));
  }
}

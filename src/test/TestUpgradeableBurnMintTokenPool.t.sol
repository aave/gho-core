// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

/// @dev These tests are specifically designed to evaluate the upgradeability mechanism introduced in the CCIP standard
/// contract BurnMintTokenPool. For testing of CCIP functionalities, please refer to the more extensive test suite
/// available at https://github.com/aave/ccip/pull/2
contract TestUpgradeableBurnMintTokenPool is TestGhoBase {
  using PercentageMath for uint256;

  address constant ARM_PROXY = address(0x20001);
  address constant ROUTER = address(0x20002);
  address constant PROXY_ADMIN = address(0x20003);
  address constant TOKEN_POOL_OWNER = address(0x20004);

  UpgradeableBurnMintTokenPool tokenPool;

  function setUp() public {
    UpgradeableBurnMintTokenPool tokenPoolImple = new UpgradeableBurnMintTokenPool(
      address(GHO_TOKEN),
      ARM_PROXY,
      ROUTER
    );

    // imple init
    tokenPoolImple.initialize(TOKEN_POOL_OWNER, ROUTER);

    // proxy deploy and init
    bytes memory tokenPoolInitParams = abi.encodeWithSignature(
      'initialize(address,address)',
      TOKEN_POOL_OWNER,
      ROUTER
    );
    TransparentUpgradeableProxy tokenPoolProxy = new TransparentUpgradeableProxy(
      address(tokenPoolImple),
      PROXY_ADMIN,
      tokenPoolInitParams
    );

    tokenPool = UpgradeableBurnMintTokenPool(address(tokenPoolProxy));

    // ownership acceptance
    vm.prank(TOKEN_POOL_OWNER);
    tokenPool.acceptOwnership();
  }

  function testInitialization() public {
    // Upgradeability
    assertEq(tokenPool.REVISION(), 1);
    vm.prank(PROXY_ADMIN);
    (bool ok, bytes memory result) = address(tokenPool).staticcall(
      abi.encodeWithSelector(TransparentUpgradeableProxy.admin.selector)
    );
    assertTrue(ok, 'proxy admin fetch failed');
    address decodedProxyAdmin = abi.decode(result, (address));
    assertEq(decodedProxyAdmin, PROXY_ADMIN, 'proxy admin is wrong');

    // TokenPool
    assertEq(tokenPool.getAllowList().length, 0);
    assertEq(tokenPool.getAllowListEnabled(), false);
    assertEq(tokenPool.getArmProxy(), ARM_PROXY);
    assertEq(tokenPool.getRouter(), ROUTER);
    assertEq(address(tokenPool.getToken()), address(GHO_TOKEN));
    assertEq(tokenPool.owner(), TOKEN_POOL_OWNER, 'owner is wrong');
  }

  function testUpgrade() public {
    MockUpgradeable newImpl = new MockUpgradeable();
    bytes memory tokenPoolInitParams = abi.encodeWithSignature('initialize()');
    vm.prank(PROXY_ADMIN);
    TransparentUpgradeableProxy(payable(address(tokenPool))).upgradeToAndCall(
      address(newImpl),
      tokenPoolInitParams
    );

    assertEq(tokenPool.REVISION(), 2);
  }

  function testRevertUpgradeUnauthorized() public {
    vm.expectRevert();
    TransparentUpgradeableProxy(payable(address(tokenPool))).upgradeToAndCall(
      address(0),
      bytes('')
    );

    vm.expectRevert();
    TransparentUpgradeableProxy(payable(address(tokenPool))).upgradeTo(address(0));
  }
}

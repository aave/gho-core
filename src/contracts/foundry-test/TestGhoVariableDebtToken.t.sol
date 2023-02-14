// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import './TestEnv.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';

contract TestGhoVariableDebtToken is Test, TestEnv {
  address public alice;
  uint256 borrowAmount = 200e18;

  function setUp() public {
    alice = users[1];

    vm.startPrank(faucet);

    WETH.mint(alice, 100 ether);

    vm.stopPrank();
  }

  function testBorrow() public {
    vm.startPrank(alice);

    POOL.borrow(address(GHO_TOKEN), borrowAmount, 2, 0, alice);

    assertEq(GHO_TOKEN.balanceOf(alice), borrowAmount, 'Gho amount doest not match borrow');
    assertEq(GHO_TOKEN.totalSupply(), borrowAmount, 'Gho total supply does not match borrow');
    assertEq(
      GHO_DEBT_TOKEN.scaledBalanceOf(alice),
      borrowAmount,
      'Gho debt token does not match borrow'
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
  }
}

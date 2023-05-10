// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import './TestGhoBase.t.sol';

contract TestGhoManager is TestGhoBase {
  function testUpdateDiscountRateStrategy() public {
    vm.expectEmit(true, true, false, true, address(GHO_DEBT_TOKEN));
    emit DiscountRateStrategyUpdated(
      address(GHO_DISCOUNT_STRATEGY),
      address(GHO_DISCOUNT_STRATEGY)
    );
    GHO_MANAGER.updateDiscountRateStrategy(address(GHO_DEBT_TOKEN), address(GHO_DISCOUNT_STRATEGY));
  }

  function testRevertUnauthorizedUpdateDiscountRateStrategy() public {
    vm.prank(ALICE);
    vm.expectRevert();
    GHO_MANAGER.updateDiscountRateStrategy(address(GHO_DEBT_TOKEN), address(GHO_DISCOUNT_STRATEGY));
  }

  function testSetReserveInterestRateStrategy() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    GhoInterestRateStrategy newInterestStrategy = new GhoInterestRateStrategy(2e25);
    vm.expectEmit(true, true, true, true, address(CONFIGURATOR));
    emit ReserveInterestRateStrategyChanged(
      address(GHO_TOKEN),
      oldInterestStrategy,
      address(newInterestStrategy)
    );
    GHO_MANAGER.setReserveInterestRateStrategyAddress(
      address(CONFIGURATOR),
      address(GHO_TOKEN),
      address(newInterestStrategy)
    );
  }

  function testRevertUnauthorizedSetReserveInterestRateStrategy() public {
    GhoInterestRateStrategy newInterestStrategy = new GhoInterestRateStrategy(2e25);
    vm.prank(ALICE);
    vm.expectRevert();
    GHO_MANAGER.setReserveInterestRateStrategyAddress(
      address(CONFIGURATOR),
      address(GHO_TOKEN),
      address(newInterestStrategy)
    );
  }
}

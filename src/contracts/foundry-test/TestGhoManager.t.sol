// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import './TestEnv.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {DebtUtils} from './libraries/DebtUtils.sol';
import {GhoActions} from './libraries/GhoActions.sol';
import {GhoManager} from '../facilitators/aave/misc/GhoManager.sol';

contract TestGhoManager is Test, GhoActions {
  GhoManager ghoManager;
  address public alice;

  event DiscountRateStrategyUpdated(
    address indexed oldDiscountRateStrategy,
    address indexed newDiscountRateStrategy
  );

  event ReserveInterestRateStrategyChanged(
    address indexed asset,
    address oldStrategy,
    address newStrategy
  );

  function setUp() public {
    ghoManager = new GhoManager();
    alice = users[0];
  }

  function testUpdateDiscountRateStrategy() public {
    vm.expectEmit(true, true, false, true, address(GHO_DEBT_TOKEN));
    emit DiscountRateStrategyUpdated(
      address(GHO_DISCOUNT_STRATEGY),
      address(GHO_DISCOUNT_STRATEGY)
    );
    ghoManager.updateDiscountRateStrategy(address(GHO_DEBT_TOKEN), address(GHO_DISCOUNT_STRATEGY));
  }

  function testRevertUnauthorizedUpdateDiscountRateStrategy() public {
    vm.prank(alice);
    vm.expectRevert();
    ghoManager.updateDiscountRateStrategy(address(GHO_DEBT_TOKEN), address(GHO_DISCOUNT_STRATEGY));
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
    ghoManager.setReserveInterestRateStrategyAddress(
      address(CONFIGURATOR),
      address(GHO_TOKEN),
      address(newInterestStrategy)
    );
  }

  function testRevertUnauthorizedSetReserveInterestRateStrategy() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    GhoInterestRateStrategy newInterestStrategy = new GhoInterestRateStrategy(2e25);
    vm.prank(alice);
    vm.expectRevert();
    ghoManager.setReserveInterestRateStrategyAddress(
      address(CONFIGURATOR),
      address(GHO_TOKEN),
      address(newInterestStrategy)
    );
  }
}

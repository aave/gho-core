// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestFixedRateStrategyFactory is TestGhoBase {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  function testConstructor() public {
    assertEq(FIXED_RATE_STRATEGY_FACTORY.POOL_ADDRESSES_PROVIDER(), address(PROVIDER));
    address[] memory strategies = FIXED_RATE_STRATEGY_FACTORY.getAllStrategies();

    assertEq(strategies.length, 0);
  }

  function testRevertConstructorInvalidExecutor() public {
    vm.expectRevert('INVALID_ADDRESSES_PROVIDER');
    new FixedRateStrategyFactory(address(0));
  }

  function testCreateStrategies() public {
    uint256[] memory rates = new uint256[](1);
    rates[0] = 100;

    address[] memory strategies = FIXED_RATE_STRATEGY_FACTORY.createStrategies(rates);

    assertEq(strategies.length, 1);
    assertEq(GhoInterestRateStrategy(strategies[0]).getBaseVariableBorrowRate(), rates[0]);
  }

  function testCreateStrategiesMultiple() public {
    uint256[] memory rates = new uint256[](3);
    rates[0] = 100;
    rates[1] = 200;
    rates[2] = 300;

    address[] memory strategies = FIXED_RATE_STRATEGY_FACTORY.createStrategies(rates);

    assertEq(strategies.length, 3);
    assertEq(GhoInterestRateStrategy(strategies[0]).getBaseVariableBorrowRate(), rates[0]);
    assertEq(GhoInterestRateStrategy(strategies[1]).getBaseVariableBorrowRate(), rates[1]);
    assertEq(GhoInterestRateStrategy(strategies[2]).getBaseVariableBorrowRate(), rates[2]);
  }

  function testCreateStrategiesCached() public {
    uint256[] memory rates = new uint256[](2);
    rates[0] = 100;
    rates[1] = 100;
    address[] memory strategies = FIXED_RATE_STRATEGY_FACTORY.createStrategies(rates);

    assertEq(strategies.length, 2);
    assertEq(strategies[0], strategies[1]);
  }

  function testCreatedStrategiesCachedDifferentCalls() public {
    uint256[] memory rates = new uint256[](1);
    rates[0] = 100;
    address[] memory strategies = FIXED_RATE_STRATEGY_FACTORY.createStrategies(rates);
    address[] memory strategies2 = FIXED_RATE_STRATEGY_FACTORY.createStrategies(rates);
    assertEq(strategies[0], strategies2[0]);
  }

  function testGetAllStrategies() public {
    uint256[] memory rates = new uint256[](3);
    rates[0] = 100;
    rates[1] = 200;
    rates[2] = 300;

    address[] memory strategies = FIXED_RATE_STRATEGY_FACTORY.createStrategies(rates);
    address[] memory strategiesCall = FIXED_RATE_STRATEGY_FACTORY.getAllStrategies();

    assertEq(strategies.length, strategiesCall.length);
    assertEq(strategies[0], strategiesCall[0]);
    assertEq(strategies[1], strategiesCall[1]);
    assertEq(strategies[2], strategiesCall[2]);
  }

  function testGetAllStrategiesCached() public {
    uint256[] memory rates = new uint256[](2);
    rates[0] = 100;
    rates[1] = 100;

    FIXED_RATE_STRATEGY_FACTORY.createStrategies(rates);
    address[] memory strategies = FIXED_RATE_STRATEGY_FACTORY.getAllStrategies();
    assertEq(strategies.length, 1);
  }

  function testGetStrategyByRate() public {
    uint256[] memory rates = new uint256[](3);
    rates[0] = 100;
    rates[1] = 200;
    rates[2] = 300;

    address[] memory strategies = FIXED_RATE_STRATEGY_FACTORY.createStrategies(rates);

    assertEq(FIXED_RATE_STRATEGY_FACTORY.getStrategyByRate(rates[0]), strategies[0]);
    assertEq(FIXED_RATE_STRATEGY_FACTORY.getStrategyByRate(rates[1]), strategies[1]);
    assertEq(FIXED_RATE_STRATEGY_FACTORY.getStrategyByRate(rates[2]), strategies[2]);
  }
}

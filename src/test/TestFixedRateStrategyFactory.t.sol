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

  function testInitialize() public {
    address[] memory strategies = new address[](1);
    strategies[0] = address(new GhoInterestRateStrategy(address(PROVIDER), 100));

    vm.expectEmit(true, true, false, false, address(FIXED_RATE_STRATEGY_FACTORY));
    emit RateStrategyCreated(strategies[0], 100);

    FIXED_RATE_STRATEGY_FACTORY.initialize(strategies);
    address[] memory strategiesCall = FIXED_RATE_STRATEGY_FACTORY.getAllStrategies();

    assertEq(strategiesCall.length, 1);
    assertEq(strategiesCall[0], strategies[0]);
  }

  function testInitializeMultiple() public {
    address[] memory strategies = new address[](3);
    strategies[0] = address(new GhoInterestRateStrategy(address(PROVIDER), 100));
    strategies[1] = address(new GhoInterestRateStrategy(address(PROVIDER), 200));
    strategies[2] = address(new GhoInterestRateStrategy(address(PROVIDER), 300));

    vm.expectEmit(true, true, false, false, address(FIXED_RATE_STRATEGY_FACTORY));
    emit RateStrategyCreated(strategies[0], 100);
    vm.expectEmit(true, true, false, false, address(FIXED_RATE_STRATEGY_FACTORY));
    emit RateStrategyCreated(strategies[1], 200);
    vm.expectEmit(true, true, false, false, address(FIXED_RATE_STRATEGY_FACTORY));
    emit RateStrategyCreated(strategies[2], 300);

    FIXED_RATE_STRATEGY_FACTORY.initialize(strategies);
    address[] memory strategiesCall = FIXED_RATE_STRATEGY_FACTORY.getAllStrategies();

    assertEq(strategiesCall.length, 3);
    assertEq(strategiesCall[0], strategies[0]);
    assertEq(strategiesCall[1], strategies[1]);
    assertEq(strategiesCall[2], strategies[2]);
  }

  function testRevertInitializeTwice() public {
    address[] memory strategies = new address[](1);
    strategies[0] = address(new GhoInterestRateStrategy(address(PROVIDER), 100));

    FIXED_RATE_STRATEGY_FACTORY.initialize(strategies);
    vm.expectRevert('Contract instance has already been initialized');
    FIXED_RATE_STRATEGY_FACTORY.initialize(strategies);
  }

  function testCreateStrategies() public {
    uint256[] memory rates = new uint256[](1);
    rates[0] = 100;

    uint256 nonce = vm.getNonce(address(FIXED_RATE_STRATEGY_FACTORY));
    address deployedStrategy = computeCreateAddress(address(FIXED_RATE_STRATEGY_FACTORY), nonce);
    vm.expectEmit(true, true, false, false, address(FIXED_RATE_STRATEGY_FACTORY));
    emit RateStrategyCreated(deployedStrategy, 100);

    address[] memory strategies = FIXED_RATE_STRATEGY_FACTORY.createStrategies(rates);

    assertEq(strategies.length, 1);
    assertEq(GhoInterestRateStrategy(strategies[0]).getBaseVariableBorrowRate(), rates[0]);
  }

  function testCreateStrategiesMultiple() public {
    uint256[] memory rates = new uint256[](3);
    rates[0] = 100;
    rates[1] = 200;
    rates[2] = 300;

    uint256 nonce = vm.getNonce(address(FIXED_RATE_STRATEGY_FACTORY));

    address deployedStrategy1 = computeCreateAddress(address(FIXED_RATE_STRATEGY_FACTORY), nonce);
    vm.expectEmit(true, true, false, false, address(FIXED_RATE_STRATEGY_FACTORY));
    emit RateStrategyCreated(deployedStrategy1, 100);

    address deployedStrategy2 = computeCreateAddress(
      address(FIXED_RATE_STRATEGY_FACTORY),
      nonce + 1
    );
    vm.expectEmit(true, true, false, false, address(FIXED_RATE_STRATEGY_FACTORY));
    emit RateStrategyCreated(deployedStrategy2, 200);

    address deployedStrategy3 = computeCreateAddress(
      address(FIXED_RATE_STRATEGY_FACTORY),
      nonce + 2
    );
    vm.expectEmit(true, true, false, false, address(FIXED_RATE_STRATEGY_FACTORY));
    emit RateStrategyCreated(deployedStrategy3, 300);

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

  function testGetFixedRateStrategyRevision() public {
    assertEq(FIXED_RATE_STRATEGY_FACTORY.REVISION(), FIXED_RATE_STRATEGY_FACTORY_REVISION);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoSteward is TestGhoBase {
  using PercentageMath for uint256;

  function setUp() public {
    GHO_TOKEN.grantRole(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(GHO_STEWARD));
  }

  function testConstructor() public {
    assertEq(GHO_STEWARD.MINIMUM_DELAY(), MINIMUM_DELAY);
    assertEq(GHO_STEWARD.BORROW_RATE_CHANGE_MAX(), BORROW_RATE_CHANGE_MAX);
    assertEq(GHO_STEWARD.STEWARD_LIFESPAN(), STEWARD_LIFESPAN);

    assertEq(GHO_STEWARD.POOL_ADDRESSES_PROVIDER(), address(PROVIDER));
    assertEq(GHO_STEWARD.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(GHO_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);
    assertEq(GHO_STEWARD.owner(), SHORT_EXECUTOR);

    IGhoSteward.Debounce memory timelocks = GHO_STEWARD.getTimelock();
    assertEq(timelocks.borrowRateLastUpdated, 0);
    assertEq(timelocks.bucketCapacityLastUpdated, 0);

    assertEq(GHO_STEWARD.getStewardExpiration(), block.timestamp + GHO_STEWARD.STEWARD_LIFESPAN());
  }

  function testRevertConstructorInvalidAddressesProvider() public {
    vm.expectRevert('INVALID_ADDRESSES_PROVIDER');
    new GhoSteward(address(0), address(0x002), address(0x003), address(0x004));
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('INVALID_GHO_TOKEN');
    new GhoSteward(address(0x001), address(0), address(0x003), address(0x004));
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new GhoSteward(address(0x001), address(0x002), address(0), address(0x004));
  }

  function testRevertConstructorInvalidShortExecutor() public {
    vm.expectRevert('INVALID_SHORT_EXECUTOR');
    new GhoSteward(address(0x001), address(0x002), address(0x003), address(0));
  }

  function testExtendStewardExpiration() public {
    uint40 oldExpirationTime = GHO_STEWARD.getStewardExpiration();
    uint40 newExpirationTime = oldExpirationTime + GHO_STEWARD.STEWARD_LIFESPAN();
    vm.prank(GHO_STEWARD.owner());
    vm.expectEmit(true, true, true, true, address(GHO_STEWARD));
    emit StewardExpirationUpdated(oldExpirationTime, newExpirationTime);
    GHO_STEWARD.extendStewardExpiration();
    assertEq(GHO_STEWARD.getStewardExpiration(), newExpirationTime);
  }

  function testRevertExtendStewardExpiration() public {
    vm.expectRevert(OwnableErrorsLib.CALLER_NOT_OWNER());
    vm.prank(ALICE);
    GHO_STEWARD.extendStewardExpiration();
  }

  function testUpdateBorrowRate() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy)
      .getBaseVariableBorrowRate();
    vm.expectEmit(true, true, true, false, address(CONFIGURATOR));
    emit ReserveInterestRateStrategyChanged(
      address(GHO_TOKEN),
      oldInterestStrategy,
      address(0) // deployed by GhoSteward
    );
    uint256 newBorrowRate = oldBorrowRate + 1;
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);

    IGhoSteward.Debounce memory timelocksBefore = GHO_STEWARD.getTimelock();

    assertEq(GHO_STEWARD.getAllStrategies().length, 0);

    vm.prank(RISK_COUNCIL);
    GHO_STEWARD.updateBorrowRate(newBorrowRate);

    address[] memory strategies = GHO_STEWARD.getAllStrategies();
    assertEq(strategies.length, 1);

    address newInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    assertEq(strategies[0], newInterestStrategy);
    assertEq(
      GhoInterestRateStrategy(newInterestStrategy).getBaseVariableBorrowRate(),
      newBorrowRate
    );
    IGhoSteward.Debounce memory timelocks = GHO_STEWARD.getTimelock();
    assertEq(timelocks.borrowRateLastUpdated, block.timestamp);
    assertEq(timelocks.bucketCapacityLastUpdated, timelocksBefore.bucketCapacityLastUpdated);
  }

  function testUpdateBorrowRateReuseStrategy() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy)
      .getBaseVariableBorrowRate();

    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);

    assertEq(GHO_STEWARD.getAllStrategies().length, 0);

    vm.prank(RISK_COUNCIL);
    GHO_STEWARD.updateBorrowRate(oldBorrowRate);

    assertEq(GHO_STEWARD.getAllStrategies().length, 1);

    address[] memory strategies = GHO_STEWARD.getAllStrategies();
    assertEq(strategies.length, 1);

    // New borrow rate
    uint256 newBorrowRate = oldBorrowRate + 1;
    vm.warp(block.timestamp + GHO_STEWARD.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    GHO_STEWARD.updateBorrowRate(newBorrowRate);

    strategies = GHO_STEWARD.getAllStrategies();
    assertEq(strategies.length, 2);

    address newInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    assertEq(strategies[1], newInterestStrategy);
    assertEq(
      GhoInterestRateStrategy(newInterestStrategy).getBaseVariableBorrowRate(),
      newBorrowRate
    );

    // Come back to old rate
    vm.warp(block.timestamp + GHO_STEWARD.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    GHO_STEWARD.updateBorrowRate(oldBorrowRate);

    assertEq(GHO_STEWARD.getAllStrategies().length, 2);
    assertEq(
      GhoInterestRateStrategy(POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN)))
        .getBaseVariableBorrowRate(),
      oldBorrowRate
    );
  }

  function testUpdateBorrowRateIdempotent() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy)
      .getBaseVariableBorrowRate();
    vm.expectEmit(true, true, true, false, address(CONFIGURATOR));
    emit ReserveInterestRateStrategyChanged(
      address(GHO_TOKEN),
      oldInterestStrategy,
      address(0) // deployed by GhoSteward
    );
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    GHO_STEWARD.updateBorrowRate(oldBorrowRate);

    address newInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    assertEq(
      GhoInterestRateStrategy(newInterestStrategy).getBaseVariableBorrowRate(),
      oldBorrowRate
    );
  }

  function testUpdateBorrowRateMaximumIncrease() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy)
      .getBaseVariableBorrowRate();
    vm.expectEmit(true, true, true, false, address(CONFIGURATOR));
    emit ReserveInterestRateStrategyChanged(
      address(GHO_TOKEN),
      oldInterestStrategy,
      address(0) // deployed by GhoSteward
    );

    uint256 newBorrowRate = oldBorrowRate +
      oldBorrowRate.percentMul(GHO_STEWARD.BORROW_RATE_CHANGE_MAX());

    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD.updateBorrowRate(newBorrowRate);

    address newInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    assertEq(
      GhoInterestRateStrategy(newInterestStrategy).getBaseVariableBorrowRate(),
      newBorrowRate
    );
  }

  function testUpdateBorrowRateMaximumDecrease() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy)
      .getBaseVariableBorrowRate();
    vm.expectEmit(true, true, true, false, address(CONFIGURATOR));
    emit ReserveInterestRateStrategyChanged(
      address(GHO_TOKEN),
      oldInterestStrategy,
      address(0) // deployed by GhoSteward
    );

    uint256 newBorrowRate = oldBorrowRate +
      oldBorrowRate.percentMul(GHO_STEWARD.BORROW_RATE_CHANGE_MAX());
    vm.warp(block.timestamp + GHO_STEWARD.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    GHO_STEWARD.updateBorrowRate(newBorrowRate);

    address newInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    assertEq(
      GhoInterestRateStrategy(newInterestStrategy).getBaseVariableBorrowRate(),
      newBorrowRate
    );
  }

  function testRevertUpdateBorrowRateUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    GHO_STEWARD.updateBorrowRate(123);
  }

  function testRevertUpdateBorrowRateExpiredSteward() public {
    vm.warp(block.timestamp + GHO_STEWARD.getStewardExpiration());
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('STEWARD_EXPIRED');
    GHO_STEWARD.updateBorrowRate(123);
  }

  function testRevertUpdateBorrowRateDebounceNotRespectedAtLaunch() public {
    vm.warp(GHO_STEWARD.MINIMUM_DELAY());

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_STEWARD.updateBorrowRate(123);
  }

  function testRevertUpdateBorrowRateDebounceNotRespected() public {
    // first borrow rate update
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy)
      .getBaseVariableBorrowRate();
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD.updateBorrowRate(oldBorrowRate);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_STEWARD.updateBorrowRate(123);
  }

  function testRevertUpdateBorrowRateInterestRateNotFound() public {
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);
    DataTypes.ReserveData memory mockData = POOL.getReserveData(address(GHO_TOKEN));
    mockData.interestRateStrategyAddress = address(0);
    vm.mockCall(
      address(POOL),
      abi.encodeWithSelector(IPool.getReserveData.selector, address(GHO_TOKEN)),
      abi.encode(mockData)
    );

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('GHO_INTEREST_RATE_STRATEGY_NOT_FOUND');
    GHO_STEWARD.updateBorrowRate(123);
  }

  function testRevertUpdateBorrowRateAboveMaximumIncrease() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy)
      .getBaseVariableBorrowRate();
    uint256 newBorrowRate = oldBorrowRate +
      oldBorrowRate.percentMul(GHO_STEWARD.BORROW_RATE_CHANGE_MAX()) +
      1;
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    GHO_STEWARD.updateBorrowRate(newBorrowRate);
  }

  function testRevertUpdateBorrowRateBelowMaximumDecrease() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy)
      .getBaseVariableBorrowRate();
    uint256 newBorrowRate = oldBorrowRate -
      oldBorrowRate.percentMul(GHO_STEWARD.BORROW_RATE_CHANGE_MAX()) -
      1;
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    GHO_STEWARD.updateBorrowRate(newBorrowRate);
  }

  function testUpdateBucketCapacity() public {
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newCapacity = uint128(oldCapacity) + 1;
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);

    IGhoSteward.Debounce memory timelocksBefore = GHO_STEWARD.getTimelock();

    vm.expectEmit(true, true, true, false, address(GHO_TOKEN));
    emit FacilitatorBucketCapacityUpdated(address(GHO_ATOKEN), oldCapacity, newCapacity);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD.updateBucketCapacity(newCapacity);

    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newCapacity);
    IGhoSteward.Debounce memory timelocks = GHO_STEWARD.getTimelock();
    assertEq(timelocks.borrowRateLastUpdated, timelocksBefore.borrowRateLastUpdated);
    assertEq(timelocks.bucketCapacityLastUpdated, block.timestamp);
  }

  function testUpdateBucketCapacityIdempotent() public {
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);

    IGhoSteward.Debounce memory timelocksBefore = GHO_STEWARD.getTimelock();

    vm.expectEmit(true, true, true, false, address(GHO_TOKEN));
    emit FacilitatorBucketCapacityUpdated(address(GHO_ATOKEN), oldCapacity, oldCapacity);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD.updateBucketCapacity(uint128(oldCapacity));

    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, oldCapacity);
    IGhoSteward.Debounce memory timelocks = GHO_STEWARD.getTimelock();
    assertEq(timelocks.borrowRateLastUpdated, timelocksBefore.borrowRateLastUpdated);
    assertEq(timelocks.bucketCapacityLastUpdated, block.timestamp);
  }

  function testUpdateBucketCapacityMaximumIncrease() public {
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newCapacity = uint128(oldCapacity * 2);
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);

    IGhoSteward.Debounce memory timelocksBefore = GHO_STEWARD.getTimelock();

    vm.expectEmit(true, true, true, false, address(GHO_TOKEN));
    emit FacilitatorBucketCapacityUpdated(address(GHO_ATOKEN), oldCapacity, newCapacity);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD.updateBucketCapacity(newCapacity);

    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newCapacity);
    IGhoSteward.Debounce memory timelocks = GHO_STEWARD.getTimelock();
    assertEq(timelocks.borrowRateLastUpdated, timelocksBefore.borrowRateLastUpdated);
    assertEq(timelocks.bucketCapacityLastUpdated, block.timestamp);
  }

  function testRevertUpdateBucketCapacityUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    GHO_STEWARD.updateBucketCapacity(123);
  }

  function testRevertUpdateBucketCapacityExpiredSteward() public {
    vm.warp(block.timestamp + GHO_STEWARD.getStewardExpiration());
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('STEWARD_EXPIRED');
    GHO_STEWARD.updateBucketCapacity(123);
  }

  function testRevertUpdateBucketCapacityDebounceNotRespectedAtLaunch() public {
    vm.warp(GHO_STEWARD.MINIMUM_DELAY());

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_STEWARD.updateBucketCapacity(123);
  }

  function testRevertUpdateBucketCapacityDebounceNotRespected() public {
    // first bucket capacity update
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD.updateBucketCapacity(uint128(oldCapacity));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_STEWARD.updateBucketCapacity(123);
  }

  function testRevertUpdateBucketCapacityGhoATokenNotFound() public {
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);
    DataTypes.ReserveData memory mockData = POOL.getReserveData(address(GHO_TOKEN));
    mockData.aTokenAddress = address(0);
    vm.mockCall(
      address(POOL),
      abi.encodeWithSelector(IPool.getReserveData.selector, address(GHO_TOKEN)),
      abi.encode(mockData)
    );

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('GHO_ATOKEN_NOT_FOUND');
    GHO_STEWARD.updateBucketCapacity(123);
  }

  function testRevertUpdateBucketCapacityAboveMaximumIncrease() public {
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newCapacity = uint128(oldCapacity * 2 + 1);
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    GHO_STEWARD.updateBucketCapacity(newCapacity);
  }

  function testRevertUpdateBucketCapacityBelowMaximumDecrease() public {
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newCapacity = uint128(oldCapacity - 1);
    vm.warp(GHO_STEWARD.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    GHO_STEWARD.updateBucketCapacity(newCapacity);
  }
}

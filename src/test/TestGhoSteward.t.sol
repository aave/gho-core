// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoSteward is TestGhoBase {
  using PercentageMath for uint256;

  function testConstructor() public {
    assertEq(GHO_MANAGER.AAVE_SHORT_EXECUTOR(), SHORT_EXECUTOR);
    assertEq(GHO_MANAGER.MINIMUM_DELAY(), MINIMUM_DELAY);
    assertEq(GHO_MANAGER.BORROW_RATE_CHANGE_MAX(), BORROW_RATE_CHANGE_MAX);
    assertEq(GHO_MANAGER.STEWARD_LIFESPAN(), STEWARD_LIFESPAN);

    assertEq(GHO_MANAGER.POOL_ADDRESSES_PROVIDER(), address(PROVIDER));
    assertEq(GHO_MANAGER.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(GHO_MANAGER.RISK_COUNCIL(), RISK_COUNCIL);

    IGhoSteward.Debounce memory timelocks = GHO_MANAGER.getTimelock();
    assertEq(timelocks.borrowRateLastUpdated, 0);
    assertEq(timelocks.bucketCapacityLastUpdated, 0);

    assertEq(GHO_MANAGER.getStewardExpiration(), block.timestamp + GHO_MANAGER.STEWARD_LIFESPAN());
  }

  function testRevertConstructorInvalidAddressesProvider() public {
    vm.expectRevert('INVALID_ADDRESSES_PROVIDER');
    new GhoSteward(address(0), address(0x002), address(0x003));
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('INVALID_GHO_TOKEN');
    new GhoSteward(address(0x001), address(0), address(0x003));
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new GhoSteward(address(0x001), address(0x002), address(0));
  }

  function testExtendStewardExpiration() public {
    uint40 oldExpirationTime = GHO_MANAGER.getStewardExpiration();
    uint40 newExpirationTime = oldExpirationTime + GHO_MANAGER.STEWARD_LIFESPAN();
    vm.prank(SHORT_EXECUTOR);
    GHO_MANAGER.extendStewardExpiration();
    // TODO
    // vm.expectEmit(true, true, true, true, address(GHO_MANAGER));
    // emit StewardExpirationUpdated(oldExpirationTime, newExpirationTime);
    assertEq(GHO_MANAGER.getStewardExpiration(), newExpirationTime);
  }

  function testRevertExtendStewardExpiration() public {
    vm.prank(ALICE);
    vm.expectRevert('ONLY_SHORT_EXECUTOR');
    GHO_MANAGER.extendStewardExpiration();
  }

  function testUpdateBorrowRate() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy).VARIABLE_BORROW_RATE();
    vm.expectEmit(true, true, true, false, address(CONFIGURATOR));
    emit ReserveInterestRateStrategyChanged(
      address(GHO_TOKEN),
      oldInterestStrategy,
      address(0) // deployed by GhoSteward
    );
    uint256 newBorrowRate = oldBorrowRate + 1;
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);

    IGhoSteward.Debounce memory timelocksBefore = GHO_MANAGER.getTimelock();

    vm.prank(RISK_COUNCIL);
    GHO_MANAGER.updateBorrowRate(newBorrowRate);

    address newInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    assertEq(GhoInterestRateStrategy(newInterestStrategy).VARIABLE_BORROW_RATE(), newBorrowRate);
    IGhoSteward.Debounce memory timelocks = GHO_MANAGER.getTimelock();
    assertEq(timelocks.borrowRateLastUpdated, block.timestamp);
    assertEq(timelocks.bucketCapacityLastUpdated, timelocksBefore.bucketCapacityLastUpdated);
  }

  function testUpdateBorrowRateIdempotent() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy).VARIABLE_BORROW_RATE();
    vm.expectEmit(true, true, true, false, address(CONFIGURATOR));
    emit ReserveInterestRateStrategyChanged(
      address(GHO_TOKEN),
      oldInterestStrategy,
      address(0) // deployed by GhoSteward
    );
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    GHO_MANAGER.updateBorrowRate(oldBorrowRate);

    address newInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    assertEq(GhoInterestRateStrategy(newInterestStrategy).VARIABLE_BORROW_RATE(), oldBorrowRate);
  }

  function testUpdateBorrowRateMaximumIncrease() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy).VARIABLE_BORROW_RATE();
    vm.expectEmit(true, true, true, false, address(CONFIGURATOR));
    emit ReserveInterestRateStrategyChanged(
      address(GHO_TOKEN),
      oldInterestStrategy,
      address(0) // deployed by GhoSteward
    );

    uint256 newBorrowRate = oldBorrowRate +
      oldBorrowRate.percentMul(GHO_MANAGER.BORROW_RATE_CHANGE_MAX());

    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);
    vm.prank(RISK_COUNCIL);
    GHO_MANAGER.updateBorrowRate(newBorrowRate);

    address newInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    assertEq(GhoInterestRateStrategy(newInterestStrategy).VARIABLE_BORROW_RATE(), newBorrowRate);
  }

  function testUpdateBorrowRateMaximumDecrease() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy).VARIABLE_BORROW_RATE();
    vm.expectEmit(true, true, true, false, address(CONFIGURATOR));
    emit ReserveInterestRateStrategyChanged(
      address(GHO_TOKEN),
      oldInterestStrategy,
      address(0) // deployed by GhoSteward
    );

    uint256 newBorrowRate = oldBorrowRate +
      oldBorrowRate.percentMul(GHO_MANAGER.BORROW_RATE_CHANGE_MAX());
    console2.log(oldBorrowRate.percentMul(GHO_MANAGER.BORROW_RATE_CHANGE_MAX()));
    console2.log(oldBorrowRate, newBorrowRate);
    vm.warp(block.timestamp + GHO_MANAGER.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    GHO_MANAGER.updateBorrowRate(newBorrowRate);

    address newInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    assertEq(GhoInterestRateStrategy(newInterestStrategy).VARIABLE_BORROW_RATE(), newBorrowRate);
  }

  function testRevertUpdateBorrowRateUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    GHO_MANAGER.updateBorrowRate(123);
  }

  function testRevertUpdateBorrowRateExpiredSteward() public {
    vm.warp(block.timestamp + GHO_MANAGER.getStewardExpiration() + 1);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('STEWARD_EXPIRED');
    GHO_MANAGER.updateBorrowRate(123);
  }

  function testRevertUpdateBorrowRateDebounceNotRespectedAtLaunch() public {
    vm.warp(GHO_MANAGER.MINIMUM_DELAY());

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_MANAGER.updateBorrowRate(123);
  }

  function testRevertUpdateBorrowRateDebounceNotRespected() public {
    // first borrow rate update
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy).VARIABLE_BORROW_RATE();
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);
    vm.prank(RISK_COUNCIL);
    GHO_MANAGER.updateBorrowRate(oldBorrowRate);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_MANAGER.updateBorrowRate(123);
  }

  function testRevertUpdateBorrowRateInterestRateNotFound() public {
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);
    DataTypes.ReserveData memory mockData = POOL.getReserveData(address(GHO_TOKEN));
    mockData.interestRateStrategyAddress = address(0);
    vm.mockCall(
      address(POOL),
      abi.encodeWithSelector(IPool.getReserveData.selector, address(GHO_TOKEN)),
      abi.encode(mockData)
    );

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('GHO_INTEREST_RATE_STRATEGY_NOT_FOUND');
    GHO_MANAGER.updateBorrowRate(123);
  }

  function testRevertUpdateBorrowRateAboveMaximumIncrease() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy).VARIABLE_BORROW_RATE();
    uint256 newBorrowRate = oldBorrowRate +
      oldBorrowRate.percentMul(GHO_MANAGER.BORROW_RATE_CHANGE_MAX()) +
      1;
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    GHO_MANAGER.updateBorrowRate(newBorrowRate);
  }

  function testRevertUpdateBorrowRateBelowMaximumDecrease() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy).VARIABLE_BORROW_RATE();
    uint256 newBorrowRate = oldBorrowRate -
      oldBorrowRate.percentMul(GHO_MANAGER.BORROW_RATE_CHANGE_MAX()) -
      1;
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    GHO_MANAGER.updateBorrowRate(newBorrowRate);
  }

  function testUpdateBucketCapacity() public {
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newCapacity = uint128(oldCapacity) + 1;
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);

    IGhoSteward.Debounce memory timelocksBefore = GHO_MANAGER.getTimelock();

    vm.expectEmit(true, true, true, false, address(GHO_TOKEN));
    emit FacilitatorBucketCapacityUpdated(address(GHO_ATOKEN), oldCapacity, newCapacity);
    vm.prank(RISK_COUNCIL);
    GHO_MANAGER.updateBucketCapacity(newCapacity);

    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newCapacity);
    IGhoSteward.Debounce memory timelocks = GHO_MANAGER.getTimelock();
    assertEq(timelocks.borrowRateLastUpdated, timelocksBefore.borrowRateLastUpdated);
    assertEq(timelocks.bucketCapacityLastUpdated, block.timestamp);
  }

  function testUpdateBucketCapacityIdempotent() public {
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);

    IGhoSteward.Debounce memory timelocksBefore = GHO_MANAGER.getTimelock();

    vm.expectEmit(true, true, true, false, address(GHO_TOKEN));
    emit FacilitatorBucketCapacityUpdated(address(GHO_ATOKEN), oldCapacity, oldCapacity);
    vm.prank(RISK_COUNCIL);
    GHO_MANAGER.updateBucketCapacity(uint128(oldCapacity));

    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, oldCapacity);
    IGhoSteward.Debounce memory timelocks = GHO_MANAGER.getTimelock();
    assertEq(timelocks.borrowRateLastUpdated, timelocksBefore.borrowRateLastUpdated);
    assertEq(timelocks.bucketCapacityLastUpdated, block.timestamp);
  }

  function testUpdateBucketCapacityMaximumIncrease() public {
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newCapacity = uint128(oldCapacity * 2);
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);

    IGhoSteward.Debounce memory timelocksBefore = GHO_MANAGER.getTimelock();

    vm.expectEmit(true, true, true, false, address(GHO_TOKEN));
    emit FacilitatorBucketCapacityUpdated(address(GHO_ATOKEN), oldCapacity, newCapacity);
    vm.prank(RISK_COUNCIL);
    GHO_MANAGER.updateBucketCapacity(newCapacity);

    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newCapacity);
    IGhoSteward.Debounce memory timelocks = GHO_MANAGER.getTimelock();
    assertEq(timelocks.borrowRateLastUpdated, timelocksBefore.borrowRateLastUpdated);
    assertEq(timelocks.bucketCapacityLastUpdated, block.timestamp);
  }

  function testRevertUpdateBucketCapacityUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    GHO_MANAGER.updateBucketCapacity(123);
  }

  function testRevertUpdateBucketCapacityExpiredSteward() public {
    vm.warp(block.timestamp + GHO_MANAGER.getStewardExpiration() + 1);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('STEWARD_EXPIRED');
    GHO_MANAGER.updateBucketCapacity(123);
  }

  function testRevertUpdateBucketCapacityDebounceNotRespectedAtLaunch() public {
    vm.warp(GHO_MANAGER.MINIMUM_DELAY());

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_MANAGER.updateBucketCapacity(123);
  }

  function testRevertUpdateBucketCapacityDebounceNotRespected() public {
    // first bucket capacity update
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);
    vm.prank(RISK_COUNCIL);
    GHO_MANAGER.updateBucketCapacity(uint128(oldCapacity));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_MANAGER.updateBucketCapacity(123);
  }

  function testRevertUpdateBucketCapacityGhoATokenNotFound() public {
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);
    DataTypes.ReserveData memory mockData = POOL.getReserveData(address(GHO_TOKEN));
    mockData.aTokenAddress = address(0);
    vm.mockCall(
      address(POOL),
      abi.encodeWithSelector(IPool.getReserveData.selector, address(GHO_TOKEN)),
      abi.encode(mockData)
    );

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('GHO_ATOKEN_NOT_FOUND');
    GHO_MANAGER.updateBucketCapacity(123);
  }

  function testRevertUpdateBucketCapacityAboveMaximumIncrease() public {
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newCapacity = uint128(oldCapacity * 2 + 1);
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    GHO_MANAGER.updateBucketCapacity(newCapacity);
  }

  function testRevertUpdateBucketCapacityBelowMaximumDecrease() public {
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newCapacity = uint128(oldCapacity - 1);
    vm.warp(GHO_MANAGER.MINIMUM_DELAY() + 1);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    GHO_MANAGER.updateBucketCapacity(newCapacity);
  }
}

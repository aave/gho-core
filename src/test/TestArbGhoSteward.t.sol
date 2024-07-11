// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import {RateLimiter} from 'ccip/v0.8/ccip/libraries/RateLimiter.sol';

contract TestArbGhoSteward is TestGhoBase {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  event ChainConfigured(
    uint64 remoteChainSelector,
    RateLimiter.Config outboundRateLimiterConfig,
    RateLimiter.Config inboundRateLimiterConfig
  );

  function setUp() public {
    /// @dev Since block.timestamp starts at 0 this is a necessary condition (block.timestamp > `MINIMUM_DELAY`) for the timelocked contract methods to work.
    vm.warp(ARB_GHO_STEWARD.MINIMUM_DELAY() + 1);
  }

  function testConstructor() public {
    assertEq(ARB_GHO_STEWARD.GHO_BORROW_RATE_CHANGE_MAX(), GHO_BORROW_RATE_CHANGE_MAX);
    assertEq(ARB_GHO_STEWARD.GSM_FEE_RATE_CHANGE_MAX(), GSM_FEE_RATE_CHANGE_MAX);
    assertEq(ARB_GHO_STEWARD.GHO_BORROW_RATE_MAX(), GHO_BORROW_RATE_MAX);
    assertEq(ARB_GHO_STEWARD.MINIMUM_DELAY(), MINIMUM_DELAY_V2);

    assertEq(ARB_GHO_STEWARD.owner(), SHORT_EXECUTOR);
    assertEq(ARB_GHO_STEWARD.POOL_ADDRESSES_PROVIDER(), address(PROVIDER));
    assertEq(ARB_GHO_STEWARD.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(ARB_GHO_STEWARD.GHO_TOKEN_POOL(), address(ARB_GHO_TOKEN_POOL));
    assertEq(ARB_GHO_STEWARD.FIXED_RATE_STRATEGY_FACTORY(), address(FIXED_RATE_STRATEGY_FACTORY));
    assertEq(ARB_GHO_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);

    IArbGhoSteward.GhoDebounce memory ghoTimelocks = ARB_GHO_STEWARD.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowCapLastUpdate, 0);
    assertEq(ghoTimelocks.ghoBorrowRateLastUpdate, 0);

    address[] memory controlledFacilitators = ARB_GHO_STEWARD.getControlledFacilitators();
    assertEq(controlledFacilitators.length, 2);

    uint40 facilitatorTimelock = ARB_GHO_STEWARD.getFacilitatorBucketCapacityTimelock(
      controlledFacilitators[0]
    );
    assertEq(facilitatorTimelock, 0);

    address[] memory gsmFeeStrategies = ARB_GHO_STEWARD.getGsmFeeStrategies();
    assertEq(gsmFeeStrategies.length, 0);
  }

  function testRevertConstructorInvalidExecutor() public {
    vm.expectRevert('INVALID_OWNER');
    new ArbGhoSteward(
      address(0),
      address(0x002),
      address(0x003),
      address(0x004),
      address(0x005),
      address(0x006)
    );
  }

  function testRevertConstructorInvalidAddressesProvider() public {
    vm.expectRevert('INVALID_ADDRESSES_PROVIDER');
    new ArbGhoSteward(
      address(0x001),
      address(0),
      address(0x003),
      address(0x004),
      address(0x005),
      address(0x006)
    );
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('INVALID_GHO_TOKEN');
    new ArbGhoSteward(
      address(0x001),
      address(0x002),
      address(0),
      address(0x004),
      address(0x005),
      address(0x006)
    );
  }

  function testRevertConstructorInvalidGhoTokenPool() public {
    vm.expectRevert('INVALID_GHO_TOKEN_POOL');
    new ArbGhoSteward(
      address(0x001),
      address(0x002),
      address(0x003),
      address(0),
      address(0x005),
      address(0x006)
    );
  }

  function testRevertConstructorInvalidFixedRateStrategyFactory() public {
    vm.expectRevert('INVALID_FIXED_RATE_STRATEGY_FACTORY');
    new ArbGhoSteward(
      address(0x001),
      address(0x002),
      address(0x003),
      address(0x004),
      address(0),
      address(0x006)
    );
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new ArbGhoSteward(
      address(0x001),
      address(0x002),
      address(0x003),
      address(0x004),
      address(0x005),
      address(0)
    );
  }

  /* TODO: Rate limit is currently restricted to only the owner
  function testUpdateRateLimit() public {
    vm.expectEmit(false, false, false, true);
    emit ChainConfigured(
      2,
      RateLimiter.Config({isEnabled: true, capacity: type(uint128).max, rate: 1e15}),
      RateLimiter.Config({isEnabled: true, capacity: type(uint128).max, rate: 1e15})
    );
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateRateLimit(
      2,
      RateLimiter.Config({isEnabled: true, capacity: type(uint128).max, rate: 1e15}),
      RateLimiter.Config({isEnabled: true, capacity: type(uint128).max, rate: 1e15})
    );
  }

  function testRevertUpdateRateLimitIfUnauthorized() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_CALLER');
    ARB_GHO_STEWARD.updateRateLimit(
      2,
      RateLimiter.Config({isEnabled: true, capacity: type(uint128).max, rate: 1e15}),
      RateLimiter.Config({isEnabled: true, capacity: type(uint128).max, rate: 1e15})
    );
  }
  */

  function testUpdateFacilitatorBucketCapacity() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    ARB_GHO_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(newBucketCapacity, capacity);
  }

  function testUpdateFacilitatorBucketCapacityMaxValue() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newBucketCapacity = uint128(currentBucketCapacity * 2);
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newBucketCapacity);
  }

  function testUpdateFacilitatorBucketCapacityTimelock() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
    uint40 timelock = ARB_GHO_STEWARD.getFacilitatorBucketCapacityTimelock(address(GHO_ATOKEN));
    assertEq(timelock, block.timestamp);
  }

  function testUpdateFacilitatorBucketCapacityAfterTimelock() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    ARB_GHO_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    skip(ARB_GHO_STEWARD.MINIMUM_DELAY() + 1);
    uint128 newBucketCapacityAfterTimelock = newBucketCapacity + 1;
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      newBucketCapacityAfterTimelock
    );
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newBucketCapacityAfterTimelock);
  }

  function testRevertUpdateFacilitatorBucketCapacityIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    ARB_GHO_STEWARD.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), 123);
  }

  function testRevertUpdateFaciltatorBucketCapacityIfUpdatedTooSoon() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    ARB_GHO_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 2
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfFacilitatorNotInControl() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('FACILITATOR_NOT_CONTROLLED');
    ARB_GHO_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_GSM_4626),
      uint128(currentBucketCapacity) + 1
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfStewardLostBucketManagerRole() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    GHO_TOKEN.revokeRole(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(ARB_GHO_STEWARD));
    vm.expectRevert(
      AccessControlErrorsLib.MISSING_ROLE(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(ARB_GHO_STEWARD))
    );
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfMoreThanDouble() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    ARB_GHO_STEWARD.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity * 2) + 1
    );
  }

  function testUpdateGhoBorrowRateUpwards() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + 1;
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateDownwards() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - 1;
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateMaxValue() public {
    uint256 ghoBorrowRateMax = ARB_GHO_STEWARD.GHO_BORROW_RATE_MAX();
    (, uint256 oldBorrowRate) = _setGhoBorrowRateViaConfigurator(ghoBorrowRateMax - 1);
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateGhoBorrowRate(ghoBorrowRateMax);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, ghoBorrowRateMax);
  }

  function testUpdateGhoBorrowRateMaxIncrement() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + ARB_GHO_STEWARD.GHO_BORROW_RATE_CHANGE_MAX();
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateDecrement() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - 1;
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateMaxDecrement() public {
    vm.startPrank(RISK_COUNCIL);

    // set a high borrow rate
    ARB_GHO_STEWARD.updateGhoBorrowRate(ARB_GHO_STEWARD.GHO_BORROW_RATE_CHANGE_MAX() + 1);
    vm.warp(block.timestamp + ARB_GHO_STEWARD.MINIMUM_DELAY() + 1);

    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - ARB_GHO_STEWARD.GHO_BORROW_RATE_CHANGE_MAX();
    ARB_GHO_STEWARD.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);

    vm.stopPrank();
  }

  function testUpdateGhoBorrowRateTimelock() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateGhoBorrowRate(oldBorrowRate + 1);
    IArbGhoSteward.GhoDebounce memory ghoTimelocks = ARB_GHO_STEWARD.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowRateLastUpdate, block.timestamp);
  }

  function testUpdateGhoBorrowRateAfterTimelock() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateGhoBorrowRate(oldBorrowRate + 1);
    skip(ARB_GHO_STEWARD.MINIMUM_DELAY() + 1);
    uint256 newBorrowRate = oldBorrowRate + 2;
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testRevertUpdateGhoBorrowRateIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    ARB_GHO_STEWARD.updateGhoBorrowRate(0.07e4);
  }

  function testRevertUpdateGhoBorrowRateIfUpdatedTooSoon() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy)
      .getBaseVariableBorrowRate();
    vm.prank(RISK_COUNCIL);
    uint256 newBorrowRate = oldBorrowRate + 1;
    ARB_GHO_STEWARD.updateGhoBorrowRate(newBorrowRate);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    ARB_GHO_STEWARD.updateGhoBorrowRate(newBorrowRate);
  }

  function testRevertUpdateGhoBorrowRateIfInterestRateNotFound() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    DataTypes.ReserveData memory mockData = POOL.getReserveData(address(GHO_TOKEN));
    mockData.interestRateStrategyAddress = address(0);
    vm.mockCall(
      address(POOL),
      abi.encodeWithSelector(IPool.getReserveData.selector, address(GHO_TOKEN)),
      abi.encode(mockData)
    );
    vm.expectRevert('GHO_INTEREST_RATE_STRATEGY_NOT_FOUND');
    vm.prank(RISK_COUNCIL);
    ARB_GHO_STEWARD.updateGhoBorrowRate(oldBorrowRate + 1);
  }

  function testRevertUpdateGhoBorrowRateIfValueMoreThanMax() public {
    uint256 maxGhoBorrowRate = ARB_GHO_STEWARD.GHO_BORROW_RATE_MAX();
    _setGhoBorrowRateViaConfigurator(maxGhoBorrowRate);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('BORROW_RATE_HIGHER_THAN_MAX');
    ARB_GHO_STEWARD.updateGhoBorrowRate(maxGhoBorrowRate + 1);
  }

  function testRevertUpdateGhoBorrowRateIfMaxExceededUpwards() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + ARB_GHO_STEWARD.GHO_BORROW_RATE_CHANGE_MAX() + 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    ARB_GHO_STEWARD.updateGhoBorrowRate(newBorrowRate);
  }

  function testRevertUpdateGhoBorrowRateIfMaxExceededDownwards() public {
    vm.startPrank(RISK_COUNCIL);

    // set a high borrow rate
    ARB_GHO_STEWARD.updateGhoBorrowRate(ARB_GHO_STEWARD.GHO_BORROW_RATE_CHANGE_MAX() + 1);
    vm.warp(block.timestamp + ARB_GHO_STEWARD.MINIMUM_DELAY() + 1);

    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - ARB_GHO_STEWARD.GHO_BORROW_RATE_CHANGE_MAX() - 1;
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    ARB_GHO_STEWARD.updateGhoBorrowRate(newBorrowRate);

    vm.stopPrank();
  }

  function _setGhoBorrowCapViaConfigurator(uint256 newBorrowCap) internal {
    CONFIGURATOR.setBorrowCap(address(GHO_TOKEN), newBorrowCap);
  }

  function _setGhoBorrowRateViaConfigurator(
    uint256 newBorrowRate
  ) internal returns (GhoInterestRateStrategy, uint256) {
    GhoInterestRateStrategy newRateStrategy = new GhoInterestRateStrategy(
      address(PROVIDER),
      newBorrowRate
    );
    CONFIGURATOR.setReserveInterestRateStrategyAddress(
      address(GHO_TOKEN),
      address(newRateStrategy)
    );
    address currentInterestRateStrategy = POOL.getReserveInterestRateStrategyAddress(
      address(GHO_TOKEN)
    );
    uint256 currentBorrowRate = GhoInterestRateStrategy(currentInterestRateStrategy)
      .getBaseVariableBorrowRate();
    assertEq(currentInterestRateStrategy, address(newRateStrategy));
    assertEq(currentBorrowRate, newBorrowRate);
    return (newRateStrategy, newBorrowRate);
  }

  function _getGhoBorrowRate() internal view returns (uint256) {
    address currentInterestRateStrategy = POOL.getReserveInterestRateStrategyAddress(
      address(GHO_TOKEN)
    );
    return GhoInterestRateStrategy(currentInterestRateStrategy).getBaseVariableBorrowRate();
  }

  function _getGhoBorrowCap() internal view returns (uint256) {
    DataTypes.ReserveConfigurationMap memory configuration = POOL.getConfiguration(
      address(GHO_TOKEN)
    );
    return configuration.getBorrowCap();
  }
}

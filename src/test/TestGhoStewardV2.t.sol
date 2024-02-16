// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoStewardV2 is TestGhoBase {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  function setUp() public {
    vm.warp(GHO_STEWARD_V2.MINIMUM_DELAY() + 1);
  }

  function testConstructor() public {
    assertEq(GHO_STEWARD_V2.GHO_BORROW_RATE_CHANGE_MAX(), GHO_BORROW_RATE_CHANGE_MAX);
    assertEq(GHO_STEWARD_V2.GSM_FEE_RATE_CHANGE_MAX(), GSM_FEE_RATE_CHANGE_MAX);
    assertEq(GHO_STEWARD_V2.GHO_BORROW_RATE_MAX(), GHO_BORROW_RATE_MAX);
    assertEq(GHO_STEWARD_V2.MINIMUM_DELAY(), MINIMUM_DELAY_V2);

    assertEq(GHO_STEWARD_V2.POOL_ADDRESSES_PROVIDER(), address(PROVIDER));
    assertEq(GHO_STEWARD_V2.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(GHO_STEWARD_V2.RISK_COUNCIL(), RISK_COUNCIL);
    assertEq(GHO_STEWARD.owner(), SHORT_EXECUTOR);

    IGhoStewardV2.GhoDebounce memory timelocks = GHO_STEWARD_V2.getGhoTimelocks();
    assertEq(timelocks.ghoBorrowRateLastUpdated, 0);
    assertEq(timelocks.ghoBucketCapacityLastUpdated, 0);

    address[] memory approvedGsms = GHO_STEWARD_V2.getApprovedGsms();
    assertEq(approvedGsms.length, 1);

    IGhoStewardV2.GsmDebounce memory gsmTimelocks = GHO_STEWARD_V2.getGsmTimelocks(approvedGsms[0]);
    assertEq(gsmTimelocks.gsmExposureCapLastUpdated, 0);
    assertEq(gsmTimelocks.gsmBucketCapacityLastUpdated, 0);
    assertEq(gsmTimelocks.gsmFeeStrategyLastUpdated, 0);

    address[] memory gsmFeeStrategies = GHO_STEWARD_V2.getGsmFeeStrategies();
    assertEq(gsmFeeStrategies.length, 0);

    address[] memory ghoBorrowRateStrategies = GHO_STEWARD_V2.getGhoBorrowRateStrategies();
    assertEq(ghoBorrowRateStrategies.length, 0);
  }

  function testRevertConstructorInvalidAddressesProvider() public {
    vm.expectRevert('INVALID_ADDRESSES_PROVIDER');
    new GhoStewardV2(address(0), address(0x002), address(0x003), address(0x004));
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('INVALID_GHO_TOKEN');
    new GhoStewardV2(address(0x001), address(0), address(0x003), address(0x004));
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new GhoStewardV2(address(0x001), address(0x002), address(0), address(0x004));
  }

  function testRevertConstructorInvalidExecutor() public {
    vm.expectRevert('INVALID_EXECUTOR');
    new GhoStewardV2(address(0x001), address(0x002), address(0x003), address(0));
  }

  function testRevertUpdateGhoBucketCapacityIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    GHO_STEWARD_V2.updateGhoBucketCapacity(123);
  }

  function testRevertUpdateGhoBucketCapacityIfUpdatedTooSoon() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBucketCapacity(uint128(currentBucketCapacity) + 1);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_STEWARD_V2.updateGhoBucketCapacity(uint128(currentBucketCapacity) + 2);
  }

  function testRevertUpdateGhoBucketCapacityIfGhoATokenNotFound() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    DataTypes.ReserveData memory mockData = POOL.getReserveData(address(GHO_TOKEN));
    mockData.aTokenAddress = address(0);
    vm.prank(RISK_COUNCIL);
    vm.mockCall(
      address(POOL),
      abi.encodeWithSelector(IPool.getReserveData.selector, address(GHO_TOKEN)),
      abi.encode(mockData)
    );
    vm.expectRevert('GHO_ATOKEN_NOT_FOUND');
    GHO_STEWARD_V2.updateGhoBucketCapacity(uint128(currentBucketCapacity) + 1);
  }

  function testRevertUpdateGhoBucketCapacityIfValueLowerThanCurrent() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    GHO_STEWARD_V2.updateGhoBucketCapacity(uint128(currentBucketCapacity) - 1);
  }

  function testRevertUpdateGhoBucketCapacityIfMoreThanDouble() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    GHO_STEWARD_V2.updateGhoBucketCapacity(uint128(currentBucketCapacity * 2) + 1);
  }

  function testUpdateGhoBucketCapacityTimelock() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBucketCapacity(uint128(currentBucketCapacity) + 1);
    IGhoStewardV2.GhoDebounce memory timelocks = GHO_STEWARD_V2.getGhoTimelocks();
    assertEq(timelocks.ghoBucketCapacityLastUpdated, block.timestamp);
  }

  function testUpdateGhoBucketCapacityAfterTimelock() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    GHO_STEWARD_V2.updateGhoBucketCapacity(newBucketCapacity);
    skip(GHO_STEWARD_V2.MINIMUM_DELAY() + 1);
    uint128 newBucketCapacityAfterTimelock = newBucketCapacity + 1;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBucketCapacity(newBucketCapacityAfterTimelock);
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newBucketCapacityAfterTimelock);
  }

  function testUpdateGhoBucketCapacity() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    GHO_STEWARD_V2.updateGhoBucketCapacity(newBucketCapacity);
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(newBucketCapacity, capacity);
  }

  function testUpdateGhoBucketCapacityMaxValue() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newBucketCapacity = uint128(currentBucketCapacity * 2);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBucketCapacity(newBucketCapacity);
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newBucketCapacity);
  }

  function testRevertUpdateGhoBorrowRateIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    GHO_STEWARD_V2.updateGhoBorrowRate(0.07e4);
  }

  function testRevertUpdateGhoBorrowRateIfUpdatedTooSoon() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy)
      .getBaseVariableBorrowRate();
    vm.prank(RISK_COUNCIL);
    uint256 newBorrowRate = oldBorrowRate + 1;
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate);
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
    GHO_STEWARD_V2.updateGhoBorrowRate(oldBorrowRate + 1);
  }

  function testRevertUpdateGhoBorrowRateIfValueMoreThanMax() public {
    uint256 maxGhoBorrowRate = GHO_STEWARD_V2.GHO_BORROW_RATE_MAX();
    _setGhoBorrowRateViaConfigurator(maxGhoBorrowRate);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    GHO_STEWARD_V2.updateGhoBorrowRate(maxGhoBorrowRate + 1);
  }

  function testRevertUpdateGhoBorrowRateIfValueLowerThanCurrent() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    GHO_STEWARD_V2.updateGhoBorrowRate(oldBorrowRate - 1);
  }

  function testRevertUpdateGhoBorrowRateIfValueMoreThanDouble() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    GHO_STEWARD_V2.updateGhoBorrowRate(oldBorrowRate * 2 + 1);
  }

  function testUpdateGhoBorrowRateTimelock() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(oldBorrowRate + 1);
    IGhoStewardV2.GhoDebounce memory timelocks = GHO_STEWARD_V2.getGhoTimelocks();
    assertEq(timelocks.ghoBorrowRateLastUpdated, block.timestamp);
  }

  function testUpdateGhoBorrowRateAfterTimelock() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(oldBorrowRate + 1);
    skip(GHO_STEWARD_V2.MINIMUM_DELAY() + 1);
    uint256 newBorrowRate = oldBorrowRate + 2;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRate() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + 1;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateMaxValue() public {
    uint256 ghoBorrowRateMax = GHO_STEWARD_V2.GHO_BORROW_RATE_MAX();
    (, uint256 oldBorrowRate) = _setGhoBorrowRateViaConfigurator(ghoBorrowRateMax - 1);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(ghoBorrowRateMax);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, ghoBorrowRateMax);
  }

  function testUpdateGhoBorrowRateMaxIncrement() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + GHO_STEWARD_V2.GHO_BORROW_RATE_CHANGE_MAX();
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateNewStrategy() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + 1;
    address[] memory oldBorrowRateStrategies = GHO_STEWARD_V2.getGhoBorrowRateStrategies();
    assertEq(oldBorrowRateStrategies.length, 0);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate);
    address[] memory newBorrowRateStrategies = GHO_STEWARD_V2.getGhoBorrowRateStrategies();
    assertEq(newBorrowRateStrategies.length, 1);
    address currentStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    assertEq(newBorrowRateStrategies[0], currentStrategy);
  }

  function testRevertUpdateGsmExposureCapIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), 50_000_000e18);
  }

  function testUpdateGsmExposureCap() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    uint128 newExposureCap = oldExposureCap + 1;
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), newExposureCap);
    uint128 currentExposureCap = GHO_GSM.getExposureCap();
    assertEq(currentExposureCap, newExposureCap);
  }

  function testRevertUpdateGsmBucketCapacity() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    GHO_STEWARD_V2.updateGsmBucketCapacity(address(GHO_GSM), 50_000_000e18);
  }

  function testUpdateGsmBucketCapacity() public {
    (uint256 oldCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM));
    uint128 newBucketCapacity = uint128(oldCapacity) + 1;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBucketCapacity(address(GHO_GSM), newBucketCapacity);
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM));
    assertEq(newBucketCapacity, capacity);
  }
}

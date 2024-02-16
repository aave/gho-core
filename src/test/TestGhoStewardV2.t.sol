// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoStewardV2 is TestGhoBase {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  uint256 public constant INITIAL_GHO_BORROW_CAP = 25e6;

  function setUp() public {
    vm.warp(GHO_STEWARD_V2.GHO_BORROW_RATE_CHANGE_DELAY() + 1);
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
  /*
  function testRevertUpdateGhoBorrowCapIfMoreThanMax() public {
    vm.expectRevert('INVALID_BORROW_CAP_MORE_THAN_MAX');
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowCap(GHO_BORROW_CAP_MAX + 1);
  }

  function testRevertUpdateGhoBorrowCapIfLowerThanCurrent() public {
    CONFIGURATOR.setBorrowCap(address(GHO_TOKEN), INITIAL_GHO_BORROW_CAP);
    uint256 oldBorrowCap = POOL.getConfiguration(address(GHO_TOKEN)).getBorrowCap();
    vm.expectRevert('INVALID_BORROW_CAP_LOWER_THAN_CURRENT');
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowCap(oldBorrowCap - 1);
  }

  function testUpdateBorrowCap() public {
    uint256 oldBorrowCap = POOL.getConfiguration(address(GHO_TOKEN)).getBorrowCap();
    vm.prank(RISK_COUNCIL);
    uint256 newBorrowCap = oldBorrowCap + 1;
    GHO_STEWARD_V2.updateGhoBorrowCap(newBorrowCap);
    uint256 currentBorrowCap = POOL.getConfiguration(address(GHO_TOKEN)).getBorrowCap();
    assertEq(currentBorrowCap, newBorrowCap);
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
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate + 0.002e4);
  }

  function testRevertUpdateGhoBorrowRateIfValueMoreThanMax() public {
    _setGhoBorrowRateViaConfigurator(GHO_BORROW_RATE_MAX);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    GHO_STEWARD_V2.updateGhoBorrowRate(GHO_BORROW_RATE_MAX + 1);
  }

  function testRevertUpdateGhoBorrowRateIfChangeMoreThanMaxPositive() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    uint256 newBorrowRate = oldBorrowRate + GHO_BORROW_RATE_CHANGE_MAX + 1;
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate);
  }

  function testRevertUpdateGhoBorrowRateIfChangeMoreThanMaxNegative() public {
    (, uint256 oldBorrowRate) = _setGhoBorrowRateViaConfigurator(GHO_BORROW_RATE_MAX);
    vm.prank(RISK_COUNCIL);
    uint256 newBorrowRate = oldBorrowRate - GHO_BORROW_RATE_CHANGE_MAX - 1;
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate);
  }

  function testUpdateGhoBorrowRatePositive() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + 1;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateNegative() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - 1;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateMax() public {
    (, uint256 oldBorrowRate) = _setGhoBorrowRateViaConfigurator(GHO_BORROW_RATE_MAX - 1);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(GHO_BORROW_RATE_MAX);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, GHO_BORROW_RATE_MAX);
  }

  function testRevertUpdateGsmExposureCapIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    GHO_STEWARD_V2.updateGsmExposureCap(GHO_GSM, 50_000_000e18);
  }

  function testUpdateGsmExposureCap() public {
    vm.prank(RISK_COUNCIL);
    uint128 newExposureCap = 50_000_000e18;
    GHO_STEWARD_V2.updateGsmExposureCap(GHO_GSM, newExposureCap);
    uint256 currentExposureCap = GHO_GSM.getExposureCap();
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

  */
}

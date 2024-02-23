// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoStewardV2 is TestGhoBase {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  function setUp() public {
    /// @dev Since block.timestamp starts at 0 this is a necessary condition (block.timestamp > `MINIMUM_DELAY`) for the timelocked contract methods to work.
    vm.warp(GHO_STEWARD_V2.MINIMUM_DELAY() + 1);
  }

  function testConstructor() public {
    assertEq(GHO_STEWARD_V2.GHO_BORROW_RATE_CHANGE_MAX(), GHO_BORROW_RATE_CHANGE_MAX);
    assertEq(GHO_STEWARD_V2.GSM_FEE_RATE_CHANGE_MAX(), GSM_FEE_RATE_CHANGE_MAX);
    assertEq(GHO_STEWARD_V2.GHO_BORROW_RATE_MAX(), GHO_BORROW_RATE_MAX);
    assertEq(GHO_STEWARD_V2.MINIMUM_DELAY(), MINIMUM_DELAY_V2);

    assertEq(GHO_STEWARD.owner(), SHORT_EXECUTOR);
    assertEq(GHO_STEWARD_V2.POOL_ADDRESSES_PROVIDER(), address(PROVIDER));
    assertEq(GHO_STEWARD_V2.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(GHO_STEWARD_V2.RISK_COUNCIL(), RISK_COUNCIL);

    IGhoStewardV2.GhoDebounce memory ghoTimelocks = GHO_STEWARD_V2.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowCapLastUpdate, 0);
    assertEq(ghoTimelocks.ghoBorrowRateLastUpdate, 0);

    address[] memory controlledFacilitators = GHO_STEWARD_V2.getControlledFacilitators();
    assertEq(controlledFacilitators.length, 2);

    uint40 facilitatorTimelock = GHO_STEWARD_V2.getFacilitatorBucketCapacityTimelock(
      controlledFacilitators[0]
    );
    assertEq(facilitatorTimelock, 0);

    address[] memory gsmFeeStrategies = GHO_STEWARD_V2.getGsmFeeStrategies();
    assertEq(gsmFeeStrategies.length, 0);

    address[] memory ghoBorrowRateStrategies = GHO_STEWARD_V2.getGhoBorrowRateStrategies();
    assertEq(ghoBorrowRateStrategies.length, 0);
  }

  function testRevertConstructorInvalidExecutor() public {
    vm.expectRevert('INVALID_OWNER');
    new GhoStewardV2(address(0), address(0x001), address(0x002), address(3));
  }

  function testRevertConstructorInvalidAddressesProvider() public {
    vm.expectRevert('INVALID_ADDRESSES_PROVIDER');
    new GhoStewardV2(address(0x001), address(0), address(0x003), address(0x004));
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('INVALID_GHO_TOKEN');
    new GhoStewardV2(address(0x001), address(0x002), address(0), address(0x004));
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new GhoStewardV2(address(0x001), address(0x002), address(0x003), address(0));
  }

  function testUpdateFacilitatorBucketCapacity() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    GHO_STEWARD_V2.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(newBucketCapacity, capacity);
  }

  function testUpdateFacilitatorBucketCapacityMaxValue() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    uint128 newBucketCapacity = uint128(currentBucketCapacity * 2);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newBucketCapacity);
  }

  function testUpdateFacilitatorBucketCapacityTimelock() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
    uint40 timelock = GHO_STEWARD_V2.getFacilitatorBucketCapacityTimelock(address(GHO_ATOKEN));
    assertEq(timelock, block.timestamp);
  }

  function testUpdateFacilitatorBucketCapacityAfterTimelock() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    uint128 newBucketCapacity = uint128(currentBucketCapacity) + 1;
    GHO_STEWARD_V2.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), newBucketCapacity);
    skip(GHO_STEWARD_V2.MINIMUM_DELAY() + 1);
    uint128 newBucketCapacityAfterTimelock = newBucketCapacity + 1;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      newBucketCapacityAfterTimelock
    );
    (uint256 capacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    assertEq(capacity, newBucketCapacityAfterTimelock);
  }

  function testRevertUpdateFacilitatorBucketCapacityIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    GHO_STEWARD_V2.updateFacilitatorBucketCapacity(address(GHO_ATOKEN), 123);
  }

  function testRevertUpdateFaciltatorBucketCapacityIfUpdatedTooSoon() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_STEWARD_V2.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 2
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfFacilitatorNotInControl() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('FACILITATOR_NOT_CONTROLLED');
    GHO_STEWARD_V2.updateFacilitatorBucketCapacity(
      address(GHO_GSM_4626),
      uint128(currentBucketCapacity) + 1
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfStewardLostBucketManagerRole() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    GHO_TOKEN.revokeRole(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(GHO_STEWARD_V2));
    vm.expectRevert(
      AccessControlErrorsLib.MISSING_ROLE(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(GHO_STEWARD_V2))
    );
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) + 1
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfValueLowerThanCurrent() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    GHO_STEWARD_V2.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity) - 1
    );
  }

  function testRevertUpdateFacilitatorBucketCapacityIfMoreThanDouble() public {
    (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(GHO_ATOKEN));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUCKET_CAPACITY_UPDATE');
    GHO_STEWARD_V2.updateFacilitatorBucketCapacity(
      address(GHO_ATOKEN),
      uint128(currentBucketCapacity * 2) + 1
    );
  }

  function testUpdateGhoBorrowCap() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    uint256 newBorrowCap = oldBorrowCap + 1;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowCap(newBorrowCap);
    uint256 currentBorrowCap = _getGhoBorrowCap();
    assertEq(newBorrowCap, currentBorrowCap);
  }

  function testUpdateGhoBorrowCapMaxValue() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    uint256 newBorrowCap = oldBorrowCap * 2;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowCap(newBorrowCap);
    uint256 currentBorrowCap = _getGhoBorrowCap();
    assertEq(newBorrowCap, currentBorrowCap);
  }

  function testUpdateGhoBorrowCapTimelock() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowCap(oldBorrowCap + 1);
    IGhoStewardV2.GhoDebounce memory ghoTimelocks = GHO_STEWARD_V2.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowCapLastUpdate, block.timestamp);
  }

  function testUpdateGhoBorrowCapAfterTimelock() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowCap(oldBorrowCap + 1);
    skip(GHO_STEWARD_V2.MINIMUM_DELAY() + 1);
    uint256 newBorrowCap = oldBorrowCap + 2;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowCap(newBorrowCap);
    uint256 currentBorrowCap = _getGhoBorrowCap();
    assertEq(newBorrowCap, currentBorrowCap);
  }

  function testRevertUpdateGhoBorrowCapIfUnauthorized() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_CALLER');
    GHO_STEWARD_V2.updateGhoBorrowCap(50e6);
  }

  function testRevertUpdateGhoBorrowCapIfUpdatedTooSoon() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowCap(oldBorrowCap + 1);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_STEWARD_V2.updateGhoBorrowCap(oldBorrowCap + 2);
  }

  function testRevertUpdateGhoBorrowCapIfValueLowerThanCurrent() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_CAP_UPDATE');
    GHO_STEWARD_V2.updateGhoBorrowCap(oldBorrowCap - 1);
  }

  function testRevertUpdateGhoBorrowCapIfValueMoreThanDouble() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_CAP_UPDATE');
    GHO_STEWARD_V2.updateGhoBorrowCap(oldBorrowCap * 2 + 1);
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

  function testUpdateGhoBorrowRateTimelock() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(oldBorrowRate + 1);
    IGhoStewardV2.GhoDebounce memory ghoTimelocks = GHO_STEWARD_V2.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowRateLastUpdate, block.timestamp);
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

  function testUpdateGhoBorrowRateSameStrategy() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + 1;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate);
    address oldStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    address[] memory oldBorrowRateStrategies = GHO_STEWARD_V2.getGhoBorrowRateStrategies();
    assertEq(oldBorrowRateStrategies.length, 1);
    skip(GHO_STEWARD_V2.MINIMUM_DELAY() + 1);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGhoBorrowRate(newBorrowRate);
    address[] memory newBorrowRateStrategies = GHO_STEWARD_V2.getGhoBorrowRateStrategies();
    assertEq(newBorrowRateStrategies.length, 1);
    address currentStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    assertEq(oldStrategy, currentStrategy);
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
    vm.expectRevert('BORROW_RATE_HIGHER_THAN_MAX');
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

  function testUpdateGsmExposureCap() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    uint128 newExposureCap = oldExposureCap + 1;
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), newExposureCap);
    uint128 currentExposureCap = GHO_GSM.getExposureCap();
    assertEq(currentExposureCap, newExposureCap);
  }

  function testUpdateGsmExposureCapMaxValue() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    uint128 newExposureCap = oldExposureCap * 2;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), newExposureCap);
    uint128 currentExposureCap = GHO_GSM.getExposureCap();
    assertEq(currentExposureCap, newExposureCap);
  }

  function testUpdateGsmExposureCapTimelock() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), oldExposureCap + 1);
    IGhoStewardV2.GsmDebounce memory timelocks = GHO_STEWARD_V2.getGsmTimelocks(address(GHO_GSM));
    assertEq(timelocks.gsmExposureCapLastUpdated, block.timestamp);
  }

  function testUpdateGsmExposureCapAfterTimelock() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), oldExposureCap + 1);
    skip(GHO_STEWARD_V2.MINIMUM_DELAY() + 1);
    uint128 newExposureCap = oldExposureCap + 2;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), newExposureCap);
    uint128 currentExposureCap = GHO_GSM.getExposureCap();
    assertEq(currentExposureCap, newExposureCap);
  }

  function testRevertUpdateGsmExposureCapIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), 50_000_000e18);
  }

  function testRevertUpdateGsmExposureCapIfTooSoon() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), oldExposureCap + 1);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), oldExposureCap + 2);
  }

  function testRevertUpdateGsmExposureCapIfValueLowerThanCurrent() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_EXPOSURE_CAP_UPDATE');
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), oldExposureCap - 1);
  }

  function testRevertUpdateGsmExposureCapIfValueMoreThanDouble() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_EXPOSURE_CAP_UPDATE');
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), oldExposureCap * 2 + 1);
  }

  function testRevertUpdateGsmExposureCapIfStewardLostConfiguratorRole() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    GHO_GSM.revokeRole(GSM_CONFIGURATOR_ROLE, address(GHO_STEWARD_V2));
    vm.expectRevert(
      AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, address(GHO_STEWARD_V2))
    );
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmExposureCap(address(GHO_GSM), oldExposureCap + 1);
  }

  function testUpdateGsmBuySellFeesBuyFee() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    assertEq(newBuyFee, buyFee + 1);
  }

  function testUpdateGsmBuySellFeesBuyFeeMax() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    uint256 maxFeeUpdate = GHO_STEWARD_V2.GSM_FEE_RATE_CHANGE_MAX();
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + maxFeeUpdate, sellFee);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    assertEq(newBuyFee, buyFee + maxFeeUpdate);
  }

  function testUpdateGsmBuySellFeesSellFee() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee, sellFee + 1);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newSellFee = IGsmFeeStrategy(newStrategy).getSellFee(1e4);
    assertEq(newSellFee, sellFee + 1);
  }

  function testUpdateGsmBuySellFeesSellFeeMax() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    uint256 maxFeeUpdate = GHO_STEWARD_V2.GSM_FEE_RATE_CHANGE_MAX();
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee, sellFee + maxFeeUpdate);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newSellFee = IGsmFeeStrategy(newStrategy).getSellFee(1e4);
    assertEq(newSellFee, sellFee + maxFeeUpdate);
  }

  function testUpdateGsmBuySellFeesBothFees() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    uint256 newSellFee = IGsmFeeStrategy(newStrategy).getSellFee(1e4);
    assertEq(newBuyFee, buyFee + 1);
    assertEq(newSellFee, sellFee + 1);
  }

  function testUpdateGsmBuySellFeesBothFeesMax() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    uint256 maxFeeUpdate = GHO_STEWARD_V2.GSM_FEE_RATE_CHANGE_MAX();
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(
      address(GHO_GSM),
      buyFee + maxFeeUpdate,
      sellFee + maxFeeUpdate
    );
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    uint256 newSellFee = IGsmFeeStrategy(newStrategy).getSellFee(1e4);
    assertEq(newBuyFee, buyFee + maxFeeUpdate);
    assertEq(newSellFee, sellFee + maxFeeUpdate);
  }

  function testUpdateGsmBuySellFeesTimelock() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    IGhoStewardV2.GsmDebounce memory timelocks = GHO_STEWARD_V2.getGsmTimelocks(address(GHO_GSM));
    assertEq(timelocks.gsmFeeStrategyLastUpdated, block.timestamp);
  }

  function testUpdateGsmBuySellFeesAfterTimelock() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    skip(GHO_STEWARD_V2.MINIMUM_DELAY() + 1);
    uint256 newBuyFee = buyFee + 2;
    uint256 newSellFee = sellFee + 2;
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), newBuyFee, newSellFee);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 currentBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    uint256 currentSellFee = IGsmFeeStrategy(newStrategy).getSellFee(1e4);
    assertEq(currentBuyFee, newBuyFee);
    assertEq(currentSellFee, newSellFee);
  }

  function testUpdateGsmBuySellFeesNewStrategy() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    address[] memory cachedStrategies = GHO_STEWARD_V2.getGsmFeeStrategies();
    assertEq(cachedStrategies.length, 1);
    address newStrategy = GHO_GSM.getFeeStrategy();
    assertEq(newStrategy, cachedStrategies[0]);
  }

  function testUpdateGsmBuySellFeesSameStrategy() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    address oldStrategy = GHO_GSM.getFeeStrategy();
    skip(GHO_STEWARD_V2.MINIMUM_DELAY() + 1);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    address[] memory cachedStrategies = GHO_STEWARD_V2.getGsmFeeStrategies();
    assertEq(cachedStrategies.length, 1);
    address newStrategy = GHO_GSM.getFeeStrategy();
    assertEq(oldStrategy, newStrategy);
  }

  function testRevertUpdateGsmBuySellFeesIfUnauthorized() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_CALLER');
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), 0.01e4, 0.01e4);
  }

  function testRevertUpdateGsmBuySellFeesIfTooSoon() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + 2, sellFee + 2);
  }

  function testRevertUpdateGsmBuySellFeesIfStrategyNotFound() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.mockCall(
      address(GHO_GSM),
      abi.encodeWithSelector(GHO_GSM.getFeeStrategy.selector),
      abi.encode(address(0))
    );
    vm.expectRevert('GSM_FEE_STRATEGY_NOT_FOUND');
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
  }

  function testRevertUpdateGsmBuySellFeesIfBuyFeeDecrement() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUY_FEE_UPDATE');
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee - 1, sellFee);
  }

  function testRevertUpdateGsmBuySellFeesIfSellFeeDecrement() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_SELL_FEE_UPDATE');
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee, sellFee - 1);
  }

  function testRevertUpdateGsmBuySellFeesIfBothDecrement() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUY_FEE_UPDATE');
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee - 1, sellFee - 1);
  }

  function testRevertUpdateGsmBuySellFeesIfBuyFeeMoreThanMax() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 maxFeeUpdate = GHO_STEWARD_V2.GSM_FEE_RATE_CHANGE_MAX();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUY_FEE_UPDATE');
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + maxFeeUpdate + 1, sellFee);
  }

  function testRevertUpdateGsmBuySellFeesIfSellFeeMoreThanMax() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 maxFeeUpdate = GHO_STEWARD_V2.GSM_FEE_RATE_CHANGE_MAX();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_SELL_FEE_UPDATE');
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee, sellFee + maxFeeUpdate + 1);
  }

  function testRevertUpdateGsmBuySellFeesIfBothMoreThanMax() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 maxFeeUpdate = GHO_STEWARD_V2.GSM_FEE_RATE_CHANGE_MAX();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUY_FEE_UPDATE');
    GHO_STEWARD_V2.updateGsmBuySellFees(
      address(GHO_GSM),
      buyFee + maxFeeUpdate + 1,
      sellFee + maxFeeUpdate + 1
    );
  }

  function testRevertUpdateGsmBuySellFeesIfStewardLostConfiguratorRole() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    GHO_GSM.revokeRole(GSM_CONFIGURATOR_ROLE, address(GHO_STEWARD_V2));
    vm.expectRevert(
      AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, address(GHO_STEWARD_V2))
    );
    vm.prank(RISK_COUNCIL);
    GHO_STEWARD_V2.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
  }

  function testSetControlledFacilitatorAdd() public {
    address[] memory oldControlledFacilitators = GHO_STEWARD_V2.getControlledFacilitators();
    address[] memory newGsmList = new address[](1);
    newGsmList[0] = address(GHO_GSM_4626);
    vm.prank(SHORT_EXECUTOR);
    GHO_STEWARD_V2.setControlledFacilitator(newGsmList, true);
    address[] memory newControlledFacilitators = GHO_STEWARD_V2.getControlledFacilitators();
    assertEq(newControlledFacilitators.length, oldControlledFacilitators.length + 1);
    assertTrue(_contains(newControlledFacilitators, address(GHO_GSM_4626)));
  }

  function testSetControlledFacilitatorsRemove() public {
    address[] memory oldControlledFacilitators = GHO_STEWARD_V2.getControlledFacilitators();
    address[] memory disableGsmList = new address[](1);
    disableGsmList[0] = address(GHO_GSM);
    vm.prank(SHORT_EXECUTOR);
    GHO_STEWARD_V2.setControlledFacilitator(disableGsmList, false);
    address[] memory newControlledFacilitators = GHO_STEWARD_V2.getControlledFacilitators();
    assertEq(newControlledFacilitators.length, oldControlledFacilitators.length - 1);
    assertFalse(_contains(newControlledFacilitators, address(GHO_GSM)));
  }

  function testRevertSetControlledFacilitatorIfUnauthorized() public {
    vm.expectRevert('Ownable: caller is not the owner');
    vm.prank(RISK_COUNCIL);
    address[] memory newGsmList = new address[](1);
    newGsmList[0] = address(GHO_GSM_4626);
    GHO_STEWARD_V2.setControlledFacilitator(newGsmList, true);
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

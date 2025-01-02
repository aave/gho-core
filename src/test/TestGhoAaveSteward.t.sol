// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import {Constants} from './helpers/Constants.sol';
import {IGhoAaveSteward} from '../contracts/misc/interfaces/IGhoAaveSteward.sol';
import {IDefaultInterestRateStrategyV2, DefaultReserveInterestRateStrategyV2} from '../contracts/misc/dependencies/AaveV3-1.sol';

contract TestGhoAaveSteward is TestGhoBase {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  IGhoAaveSteward.BorrowRateConfig public defaultBorrowRateConfig =
    IGhoAaveSteward.BorrowRateConfig({
      optimalUsageRatioMaxChange: 5_00,
      baseVariableBorrowRateMaxChange: 5_00,
      variableRateSlope1MaxChange: 5_00,
      variableRateSlope2MaxChange: 5_00
    });
  IDefaultInterestRateStrategyV2.InterestRateData public defaultRateParams =
    IDefaultInterestRateStrategyV2.InterestRateData({
      optimalUsageRatio: 1_00,
      baseVariableBorrowRate: 0.20e4,
      variableRateSlope1: 0,
      variableRateSlope2: 0
    });

  function setUp() public {
    // Deploy Gho Aave Steward
    GHO_AAVE_STEWARD = new GhoAaveSteward(
      SHORT_EXECUTOR,
      address(PROVIDER),
      address(MOCK_POOL_DATA_PROVIDER),
      address(GHO_TOKEN),
      RISK_COUNCIL,
      defaultBorrowRateConfig
    );

    // Set a new strategy because the default is old strategy type
    DefaultReserveInterestRateStrategyV2 newRateStrategy = new DefaultReserveInterestRateStrategyV2(
      address(PROVIDER)
    );
    CONFIGURATOR.setReserveInterestRateStrategyAddress(
      address(GHO_TOKEN),
      address(newRateStrategy),
      abi.encode(defaultRateParams)
    );

    /// @dev Since block.timestamp starts at 0 this is a necessary condition (block.timestamp > `MINIMUM_DELAY`) for the timelocked contract methods to work.
    vm.warp(GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
  }

  function testConstructor() public {
    assertEq(GHO_AAVE_STEWARD.owner(), SHORT_EXECUTOR);
    assertEq(GHO_AAVE_STEWARD.MINIMUM_DELAY(), MINIMUM_DELAY_V2);

    assertEq(GHO_AAVE_STEWARD.POOL_ADDRESSES_PROVIDER(), address(PROVIDER));
    assertEq(GHO_AAVE_STEWARD.POOL_DATA_PROVIDER(), address(MOCK_POOL_DATA_PROVIDER));
    assertEq(GHO_AAVE_STEWARD.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(GHO_AAVE_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);

    IGhoAaveSteward.GhoDebounce memory ghoTimelocks = GHO_AAVE_STEWARD.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowCapLastUpdate, 0);
  }

  function testRevertConstructorInvalidOwner() public {
    vm.expectRevert('INVALID_OWNER');
    new GhoAaveSteward(
      address(0),
      address(0x002),
      address(0x003),
      address(0x004),
      address(0x005),
      defaultBorrowRateConfig
    );
  }

  function testRevertConstructorInvalidAddressesProvider() public {
    vm.expectRevert('INVALID_ADDRESSES_PROVIDER');
    new GhoAaveSteward(
      address(0x001),
      address(0),
      address(0x003),
      address(0x004),
      address(0x005),
      defaultBorrowRateConfig
    );
  }

  function testRevertConstructorInvalidDataProvider() public {
    vm.expectRevert('INVALID_DATA_PROVIDER');
    new GhoAaveSteward(
      address(0x001),
      address(0x002),
      address(0),
      address(0x004),
      address(0x005),
      defaultBorrowRateConfig
    );
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('INVALID_GHO_TOKEN');
    new GhoAaveSteward(
      address(0x001),
      address(0x002),
      address(0x003),
      address(0),
      address(0x005),
      defaultBorrowRateConfig
    );
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new GhoAaveSteward(
      address(0x001),
      address(0x002),
      address(0x003),
      address(0x004),
      address(0),
      defaultBorrowRateConfig
    );
  }

  function testChangeOwnership() public {
    address newOwner = makeAddr('newOwner');
    assertEq(GHO_AAVE_STEWARD.owner(), SHORT_EXECUTOR);
    vm.prank(SHORT_EXECUTOR);
    GHO_AAVE_STEWARD.transferOwnership(newOwner);
    assertEq(GHO_AAVE_STEWARD.owner(), newOwner);
  }

  function testChangeOwnershipRevert() public {
    vm.expectRevert('Ownable: new owner is the zero address');
    vm.prank(SHORT_EXECUTOR);
    GHO_AAVE_STEWARD.transferOwnership(address(0));
  }

  function testUpdateGhoBorrowCap() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    uint256 newBorrowCap = oldBorrowCap + 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowCap(newBorrowCap);
    uint256 currentBorrowCap = _getGhoBorrowCap();
    assertEq(newBorrowCap, currentBorrowCap);
  }

  function testUpdateGhoBorrowCapMaxIncrease() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    uint256 newBorrowCap = oldBorrowCap * 2;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowCap(newBorrowCap);
    uint256 currentBorrowCap = _getGhoBorrowCap();
    assertEq(newBorrowCap, currentBorrowCap);
  }

  function testUpdateGhoBorrowCapMaxDecrease() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowCap(0);
    uint256 currentBorrowCap = _getGhoBorrowCap();
    assertEq(currentBorrowCap, 0);
  }

  function testUpdateGhoBorrowCapTimelock() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowCap(oldBorrowCap + 1);
    IGhoAaveSteward.GhoDebounce memory ghoTimelocks = GHO_AAVE_STEWARD.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowCapLastUpdate, block.timestamp);
  }

  function testUpdateGhoBorrowCapAfterTimelock() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowCap(oldBorrowCap + 1);
    skip(GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
    uint256 newBorrowCap = oldBorrowCap + 2;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowCap(newBorrowCap);
    uint256 currentBorrowCap = _getGhoBorrowCap();
    assertEq(newBorrowCap, currentBorrowCap);
  }

  function testRevertUpdateGhoBorrowCapIfUnauthorized() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_CALLER');
    GHO_AAVE_STEWARD.updateGhoBorrowCap(50e6);
  }

  function testRevertUpdateGhoBorrowCapIfUpdatedTooSoon() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowCap(oldBorrowCap + 1);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_AAVE_STEWARD.updateGhoBorrowCap(oldBorrowCap + 2);
  }

  function testRevertUpdateGhoBorrowCapNoChange() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('NO_CHANGE_IN_BORROW_CAP');
    GHO_AAVE_STEWARD.updateGhoBorrowCap(oldBorrowCap);
  }

  function testRevertUpdateGhoBorrowCapIfValueMoreThanDouble() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_CAP_UPDATE');
    GHO_AAVE_STEWARD.updateGhoBorrowCap(oldBorrowCap * 2 + 1);
  }

  function testUpdateGhoSupplyCap() public {
    uint256 oldSupplyCap = 1e6;
    _setGhoSupplyCapViaConfigurator(oldSupplyCap);
    uint256 newSupplyCap = oldSupplyCap + 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoSupplyCap(newSupplyCap);
    uint256 currentSupplyCap = _getGhoSupplyCap();
    assertEq(newSupplyCap, currentSupplyCap);
  }

  function testUpdateGhoSupplyCapMaxIncrease() public {
    uint256 oldSupplyCap = 1e6;
    _setGhoSupplyCapViaConfigurator(oldSupplyCap);
    uint256 newSupplyCap = oldSupplyCap * 2;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoSupplyCap(newSupplyCap);
    uint256 currentSupplyCap = _getGhoSupplyCap();
    assertEq(newSupplyCap, currentSupplyCap);
  }

  function testUpdateGhoSupplyCapMaxDecrease() public {
    uint256 oldSupplyCap = 1e6;
    _setGhoSupplyCapViaConfigurator(oldSupplyCap);
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoSupplyCap(0);
    uint256 currentSupplyCap = _getGhoSupplyCap();
    assertEq(currentSupplyCap, 0);
  }

  function testUpdateGhoSupplyCapTimelock() public {
    uint256 oldSupplyCap = 1e6;
    _setGhoSupplyCapViaConfigurator(oldSupplyCap);
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoSupplyCap(oldSupplyCap + 1);
    IGhoAaveSteward.GhoDebounce memory ghoTimelocks = GHO_AAVE_STEWARD.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoSupplyCapLastUpdate, block.timestamp);
  }

  function testUpdateGhoSupplyCapAfterTimelock() public {
    uint256 oldSupplyCap = 1e6;
    _setGhoSupplyCapViaConfigurator(oldSupplyCap);
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoSupplyCap(oldSupplyCap + 1);
    skip(GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
    uint256 newSupplyCap = oldSupplyCap + 2;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoSupplyCap(newSupplyCap);
    uint256 currentSupplyCap = _getGhoSupplyCap();
    assertEq(newSupplyCap, currentSupplyCap);
  }

  function testRevertUpdateGhoSupplyCapIfUnauthorized() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_CALLER');
    GHO_AAVE_STEWARD.updateGhoSupplyCap(50e6);
  }

  function testRevertUpdateGhoSupplyCapIfUpdatedTooSoon() public {
    uint256 oldSupplyCap = 1e6;
    _setGhoSupplyCapViaConfigurator(oldSupplyCap);
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoSupplyCap(oldSupplyCap + 1);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_AAVE_STEWARD.updateGhoSupplyCap(oldSupplyCap + 2);
  }

  function testRevertUpdateGhoSupplyCapNoChange() public {
    uint256 oldSupplyCap = 1e6;
    _setGhoSupplyCapViaConfigurator(oldSupplyCap);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('NO_CHANGE_IN_SUPPLY_CAP');
    GHO_AAVE_STEWARD.updateGhoSupplyCap(oldSupplyCap);
  }

  function testRevertUpdateGhoSupplyCapIfValueMoreThanDouble() public {
    uint256 oldSupplyCap = 1e6;
    _setGhoSupplyCapViaConfigurator(oldSupplyCap);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_SUPPLY_CAP_UPDATE');
    GHO_AAVE_STEWARD.updateGhoSupplyCap(oldSupplyCap * 2 + 1);
  }

  function testUpdateGhoBorrowRate() public {
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      0.21e4,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    assertEq(_getGhoBorrowRate(), 0.21e4);
  }

  function testUpdateGhoBorrowRateUpwards() public {
    uint32 oldBorrowRate = _getGhoBorrowRate();
    uint32 newBorrowRate = oldBorrowRate + 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint32 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateUpwardsFromHigh() public {
    // set a very high borrow rate of 80%
    uint32 highBaseBorrowRate = 0.80e4;
    _setGhoBorrowRateViaConfigurator(highBaseBorrowRate);
    highBaseBorrowRate += 0.04e4;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      highBaseBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    assertEq(highBaseBorrowRate, _getGhoBorrowRate());
  }

  function testUpdateGhoBorrowRateDownwards() public {
    uint32 oldBorrowRate = _getGhoBorrowRate();
    uint32 newBorrowRate = oldBorrowRate - 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint32 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateDownwardsFromHigh() public {
    // set a very high borrow rate of 80%
    uint32 highBaseBorrowRate = 0.80e4;
    _setGhoBorrowRateViaConfigurator(highBaseBorrowRate);
    highBaseBorrowRate -= 0.04e4;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      highBaseBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    assertEq(highBaseBorrowRate, _getGhoBorrowRate());
  }

  function testUpdateGhoBorrowRateMaxIncrement() public {
    uint32 oldBorrowRate = _getGhoBorrowRate();
    uint32 newBorrowRate = oldBorrowRate + GHO_BORROW_RATE_CHANGE_MAX;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint32 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateDecrement() public {
    uint32 oldBorrowRate = _getGhoBorrowRate();
    uint32 newBorrowRate = oldBorrowRate - 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint32 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateMaxDecrement() public {
    vm.startPrank(RISK_COUNCIL);

    // set a high borrow rate
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      _getGhoBorrowRate() + GHO_BORROW_RATE_CHANGE_MAX,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    vm.warp(block.timestamp + GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);

    uint32 oldBorrowRate = _getGhoBorrowRate();
    uint32 newBorrowRate = oldBorrowRate - GHO_BORROW_RATE_CHANGE_MAX;
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint32 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);

    vm.stopPrank();
  }

  function testUpdateGhoBorrowRateTimelock() public {
    uint32 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      oldBorrowRate + 1,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    IGhoAaveSteward.GhoDebounce memory ghoTimelocks = GHO_AAVE_STEWARD.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowRateLastUpdate, block.timestamp);
  }

  function testUpdateGhoBorrowRateAfterTimelock() public {
    uint32 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      oldBorrowRate + 1,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    skip(GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
    uint32 newBorrowRate = oldBorrowRate + 2;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint32 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateOptimalUsageRatio() public {
    uint16 oldOptimalUsageRatio = _getOptimalUsageRatio();
    uint16 newOptimalUsageRatio = oldOptimalUsageRatio + 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      newOptimalUsageRatio,
      defaultRateParams.baseVariableBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint16 currentOptimalUsageRatio = _getOptimalUsageRatio();
    assertEq(currentOptimalUsageRatio, newOptimalUsageRatio);
  }

  function testRevertUpdateGhoBorrowRateOptimalUsageRatioIfMaxExceededUpwards() public {
    uint16 oldOptimalUsageRatio = _getOptimalUsageRatio();
    uint16 newOptimalUsageRatio = oldOptimalUsageRatio +
      defaultBorrowRateConfig.optimalUsageRatioMaxChange +
      1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_OPTIMAL_USAGE_RATIO');
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      newOptimalUsageRatio,
      defaultRateParams.baseVariableBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
  }

  function testRevertUpdateGhoBorrowRateOptimalUsageRatioIfMaxExceededDownwards() public {
    uint16 oldOptimalUsageRatio = _getOptimalUsageRatio();
    uint16 newOptimalUsageRatio = oldOptimalUsageRatio +
      defaultBorrowRateConfig.optimalUsageRatioMaxChange;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      newOptimalUsageRatio,
      defaultRateParams.baseVariableBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    vm.warp(block.timestamp + GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_OPTIMAL_USAGE_RATIO');
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      newOptimalUsageRatio - defaultBorrowRateConfig.optimalUsageRatioMaxChange - 1,
      defaultRateParams.baseVariableBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
  }

  function testUpdateGhoBorrowRateVariableRateSlope1() public {
    uint32 oldVariableRateSlope1 = _getVariableRateSlope1();
    uint32 newVariableRateSlope1 = oldVariableRateSlope1 + 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      defaultRateParams.baseVariableBorrowRate,
      newVariableRateSlope1,
      newVariableRateSlope1 + 1 // variableRateSlope2 has to be gte variableRateSlope1
    );
    uint32 currentVariableRateSlope1 = _getVariableRateSlope1();
    assertEq(currentVariableRateSlope1, newVariableRateSlope1);
  }

  function testRevertUpdateGhoBorrowRateVariableRateSlope1IfMaxExceededUpwards() public {
    uint32 oldVariableRateSlope1 = _getVariableRateSlope1();
    uint32 newVariableRateSlope1 = oldVariableRateSlope1 +
      defaultBorrowRateConfig.variableRateSlope1MaxChange +
      1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_VARIABLE_RATE_SLOPE1');
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      defaultRateParams.baseVariableBorrowRate,
      newVariableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
  }

  function testRevertUpdateGhoBorrowRateVariableRateSlope1IfMaxExceededDownwards() public {
    uint32 oldVariableRateSlope1 = _getVariableRateSlope1();
    uint32 newVariableRateSlope1 = oldVariableRateSlope1 +
      defaultBorrowRateConfig.variableRateSlope1MaxChange;
    _setGhoBorrowRateViaConfigurator(1); // Change Gho borrow rate to not exceed max
    uint32 ghoBorrowRate = _getGhoBorrowRate();
    vm.startPrank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      ghoBorrowRate,
      newVariableRateSlope1,
      newVariableRateSlope1 // variableRateSlope2 has to be gte variableRateSlope1
    );
    newVariableRateSlope1 += 1; // Set higher than max allowed
    vm.warp(block.timestamp + GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      ghoBorrowRate,
      newVariableRateSlope1,
      newVariableRateSlope1
    );
    vm.warp(block.timestamp + GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
    vm.expectRevert('INVALID_VARIABLE_RATE_SLOPE1');
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      ghoBorrowRate,
      newVariableRateSlope1 - defaultBorrowRateConfig.variableRateSlope1MaxChange - 1,
      newVariableRateSlope1
    );
    vm.stopPrank();
  }

  function testUpdateGhoBorrowRateVariableRateSlope2() public {
    uint32 oldVariableRateSlope2 = _getVariableRateSlope2();
    uint32 newVariableRateSlope2 = oldVariableRateSlope2 + 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      defaultRateParams.baseVariableBorrowRate,
      defaultRateParams.variableRateSlope1,
      newVariableRateSlope2
    );
    uint32 currentVariableRateSlope2 = _getVariableRateSlope2();
    assertEq(currentVariableRateSlope2, newVariableRateSlope2);
  }

  function testRevertUpdateGhoBorrowRateVariableRateSlope2IfMaxExceededUpwards() public {
    uint32 oldVariableRateSlope2 = _getVariableRateSlope2();
    uint32 newVariableRateSlope2 = oldVariableRateSlope2 +
      defaultBorrowRateConfig.variableRateSlope2MaxChange +
      1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_VARIABLE_RATE_SLOPE2');
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      defaultRateParams.baseVariableBorrowRate,
      defaultRateParams.variableRateSlope1,
      newVariableRateSlope2
    );
  }

  function testRevertUpdateGhoBorrowRateVariableRateSlope2IfMaxExceededDownwards() public {
    uint32 oldVariableRateSlope2 = _getVariableRateSlope2();
    uint32 newVariableRateSlope2 = oldVariableRateSlope2 +
      defaultBorrowRateConfig.variableRateSlope2MaxChange;
    _setGhoBorrowRateViaConfigurator(1);
    uint32 ghoBorrowRate = _getGhoBorrowRate();
    vm.startPrank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      ghoBorrowRate,
      defaultRateParams.variableRateSlope1,
      newVariableRateSlope2
    );
    newVariableRateSlope2 += 1; // Set higher than max allowed
    vm.warp(block.timestamp + GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      ghoBorrowRate,
      defaultRateParams.variableRateSlope1,
      newVariableRateSlope2
    );
    vm.warp(block.timestamp + GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
    vm.expectRevert('INVALID_VARIABLE_RATE_SLOPE2');
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      ghoBorrowRate,
      defaultRateParams.variableRateSlope1,
      newVariableRateSlope2 - defaultBorrowRateConfig.variableRateSlope2MaxChange - 1
    );
    vm.stopPrank();
  }

  function testRevertUpdateGhoBorrowRateIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      0.07e4,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
  }

  function testRevertUpdateGhoBorrowRateIfUpdatedTooSoon() public {
    uint32 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    uint32 newBorrowRate = oldBorrowRate + 1;
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
  }

  function testRevertUpdateGhoBorrowRateNoChange() public {
    uint32 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('NO_CHANGE_IN_RATES');
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      oldBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
  }

  function testRevertUpdateGhoBorrowRateIfMaxExceededUpwards() public {
    uint32 oldBorrowRate = _getGhoBorrowRate();
    uint32 newBorrowRate = oldBorrowRate + GHO_BORROW_RATE_CHANGE_MAX + 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
  }

  function testRevertUpdateGhoBorrowRateIfMaxExceededDownwards() public {
    vm.startPrank(RISK_COUNCIL);

    // set a high borrow rate
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      _getGhoBorrowRate() + GHO_BORROW_RATE_CHANGE_MAX,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    vm.warp(block.timestamp + GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);

    uint32 oldBorrowRate = _getGhoBorrowRate();
    uint32 newBorrowRate = oldBorrowRate - GHO_BORROW_RATE_CHANGE_MAX - 1;
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );

    vm.stopPrank();
  }

  function testSetRiskConfig() public {
    defaultBorrowRateConfig.optimalUsageRatioMaxChange += 1;
    vm.prank(SHORT_EXECUTOR);
    GHO_AAVE_STEWARD.setBorrowRateConfig(
      defaultBorrowRateConfig.optimalUsageRatioMaxChange,
      defaultBorrowRateConfig.baseVariableBorrowRateMaxChange,
      defaultBorrowRateConfig.variableRateSlope1MaxChange,
      defaultBorrowRateConfig.variableRateSlope2MaxChange
    );
    IGhoAaveSteward.BorrowRateConfig memory currentBorrowRateConfig = GHO_AAVE_STEWARD
      .getBorrowRateConfig();
    assertEq(
      currentBorrowRateConfig.optimalUsageRatioMaxChange,
      defaultBorrowRateConfig.optimalUsageRatioMaxChange
    );
  }

  function _setGhoBorrowCapViaConfigurator(uint256 newBorrowCap) internal {
    CONFIGURATOR.setBorrowCap(address(GHO_TOKEN), newBorrowCap);
  }

  function _getGhoBorrowCap() internal view returns (uint256) {
    DataTypes.ReserveConfigurationMap memory configuration = POOL.getConfiguration(
      address(GHO_TOKEN)
    );
    return configuration.getBorrowCap();
  }

  function _setGhoSupplyCapViaConfigurator(uint256 newSupplyCap) internal {
    CONFIGURATOR.setSupplyCap(address(GHO_TOKEN), newSupplyCap);
  }

  function _getGhoSupplyCap() internal view returns (uint256) {
    DataTypes.ReserveConfigurationMap memory configuration = POOL.getConfiguration(
      address(GHO_TOKEN)
    );
    return configuration.getSupplyCap();
  }

  function _setGhoBorrowRateViaConfigurator(uint32 newBorrowRate) internal {
    IDefaultInterestRateStrategyV2.InterestRateData
      memory rateParams = IDefaultInterestRateStrategyV2.InterestRateData({
        optimalUsageRatio: 1_00,
        baseVariableBorrowRate: newBorrowRate,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      });
    CONFIGURATOR.setReserveInterestRateData(address(GHO_TOKEN), abi.encode(rateParams));
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function _getGhoBorrowRate() internal view returns (uint32) {
    address currentInterestRateStrategy = POOL.getReserveInterestRateStrategyAddress(
      address(GHO_TOKEN)
    );
    return
      uint32(
        IDefaultInterestRateStrategyV2(currentInterestRateStrategy).getBaseVariableBorrowRate(
          address(GHO_TOKEN)
        ) / 1e23
      ); // Convert to bps
  }

  function _getOptimalUsageRatio() internal view returns (uint16) {
    address currentInterestRateStrategy = POOL.getReserveInterestRateStrategyAddress(
      address(GHO_TOKEN)
    );
    return
      uint16(
        IDefaultInterestRateStrategyV2(currentInterestRateStrategy).getOptimalUsageRatio(
          address(GHO_TOKEN)
        ) / 1e23
      ); // Convert to bps
  }

  function _getVariableRateSlope1() internal view returns (uint32) {
    address currentInterestRateStrategy = POOL.getReserveInterestRateStrategyAddress(
      address(GHO_TOKEN)
    );
    return
      uint32(
        IDefaultInterestRateStrategyV2(currentInterestRateStrategy).getVariableRateSlope1(
          address(GHO_TOKEN)
        ) / 1e23
      ); // Convert to bps
  }

  function _getVariableRateSlope2() internal view returns (uint32) {
    address currentInterestRateStrategy = POOL.getReserveInterestRateStrategyAddress(
      address(GHO_TOKEN)
    );
    return
      uint32(
        IDefaultInterestRateStrategyV2(currentInterestRateStrategy).getVariableRateSlope2(
          address(GHO_TOKEN)
        ) / 1e23
      ); // Convert to bps
  }
}

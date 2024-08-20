// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import {Constants} from './helpers/Constants.sol';
import {IGhoAaveSteward} from '../contracts/misc/interfaces/IGhoAaveSteward.sol';
import {IDefaultInterestRateStrategyV2} from '../contracts/misc/deps/Dependencies.sol';
import {DefaultReserveInterestRateStrategyV2} from '../contracts/misc/deps/Dependencies.sol';

contract TestGhoAaveSteward is TestGhoBase {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  IGhoAaveSteward.BorrowRateConfig public defaultBorrowRateConfig =
    IGhoAaveSteward.BorrowRateConfig({
      optimalUsageRatioMaxChange: 10_00,
      baseVariableBorrowRateMaxChange: 5_00,
      variableRateSlope1MaxChange: 10_00,
      variableRateSlope2MaxChange: 10_00
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
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateDownwards() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateMaxValue() public {
    uint256 ghoBorrowRateMax = GHO_AAVE_STEWARD.GHO_BORROW_RATE_MAX();
    _setGhoBorrowRateViaConfigurator(ghoBorrowRateMax - 1);
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      ghoBorrowRateMax,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, ghoBorrowRateMax);
  }

  function testUpdateGhoBorrowRateMaxIncrement() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + GHO_BORROW_RATE_CHANGE_MAX;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateDecrement() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint256 currentBorrowRate = _getGhoBorrowRate();
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

    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - GHO_BORROW_RATE_CHANGE_MAX;
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);

    vm.stopPrank();
  }

  function testUpdateGhoBorrowRateTimelock() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
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
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      oldBorrowRate + 1,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    skip(GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
    uint256 newBorrowRate = oldBorrowRate + 2;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      newBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateOptimalUsageRatio() public {
    uint256 oldOptimalUsageRatio = _getOptimalUsageRatio();
    uint256 newOptimalUsageRatio = oldOptimalUsageRatio + 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      newOptimalUsageRatio,
      defaultRateParams.baseVariableBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
    uint256 currentOptimalUsageRatio = _getOptimalUsageRatio();
    assertEq(currentOptimalUsageRatio, newOptimalUsageRatio);
  }

  function testRevertUpdateGhoBorrowRateOptimalUsageRatioIfMaxExceededUpwards() public {
    uint256 oldOptimalUsageRatio = _getOptimalUsageRatio();
    uint256 newOptimalUsageRatio = oldOptimalUsageRatio +
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
    uint256 oldOptimalUsageRatio = _getOptimalUsageRatio();
    uint256 newOptimalUsageRatio = oldOptimalUsageRatio +
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
    uint256 oldVariableRateSlope1 = _getVariableRateSlope1();
    uint256 newVariableRateSlope1 = oldVariableRateSlope1 + 1;
    vm.prank(RISK_COUNCIL);
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      defaultRateParams.baseVariableBorrowRate,
      newVariableRateSlope1,
      newVariableRateSlope1 + 1 // variableRateSlope2 has to be gte variableRateSlope1
    );
    uint256 currentVariableRateSlope1 = _getVariableRateSlope1();
    assertEq(currentVariableRateSlope1, newVariableRateSlope1);
  }

  function testRevertUpdateGhoBorrowRateVariableRateSlope1IfMaxExceededUpwards() public {
    uint256 oldVariableRateSlope1 = _getVariableRateSlope1();
    uint256 newVariableRateSlope1 = oldVariableRateSlope1 +
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
    uint256 oldVariableRateSlope1 = _getVariableRateSlope1();
    uint256 newVariableRateSlope1 = oldVariableRateSlope1 +
      defaultBorrowRateConfig.variableRateSlope1MaxChange;
    _setGhoBorrowRateViaConfigurator(1); // Change Gho borrow rate to not exceed max
    uint256 ghoBorrowRate = _getGhoBorrowRate();
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
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    uint256 newBorrowRate = oldBorrowRate + 1;
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
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('NO_CHANGE_IN_RATES');
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      oldBorrowRate,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
  }

  function testRevertUpdateGhoBorrowRateIfValueMoreThanMax() public {
    address currentInterestRateStrategy = POOL.getReserveInterestRateStrategyAddress(
      address(GHO_TOKEN)
    );
    uint256 maxGhoBorrowRate = IDefaultInterestRateStrategyV2(currentInterestRateStrategy)
      .MAX_BORROW_RATE();
    _setGhoBorrowRateViaConfigurator(maxGhoBorrowRate);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('BORROW_RATE_HIGHER_THAN_MAX');
    GHO_AAVE_STEWARD.updateGhoBorrowRate(
      defaultRateParams.optimalUsageRatio,
      maxGhoBorrowRate + 1,
      defaultRateParams.variableRateSlope1,
      defaultRateParams.variableRateSlope2
    );
  }

  function testRevertUpdateGhoBorrowRateIfMaxExceededUpwards() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + GHO_BORROW_RATE_CHANGE_MAX + 1;
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

    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - GHO_BORROW_RATE_CHANGE_MAX - 1;
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

  function testSetRiskConfigIfUpdatedTooSoon() public {
    vm.prank(SHORT_EXECUTOR);
    GHO_AAVE_STEWARD.setBorrowRateConfig(
      defaultBorrowRateConfig.optimalUsageRatioMaxChange,
      defaultBorrowRateConfig.baseVariableBorrowRateMaxChange,
      defaultBorrowRateConfig.variableRateSlope1MaxChange,
      defaultBorrowRateConfig.variableRateSlope2MaxChange
    );
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    vm.prank(SHORT_EXECUTOR);
    GHO_AAVE_STEWARD.setBorrowRateConfig(
      defaultBorrowRateConfig.optimalUsageRatioMaxChange,
      defaultBorrowRateConfig.baseVariableBorrowRateMaxChange,
      defaultBorrowRateConfig.variableRateSlope1MaxChange,
      defaultBorrowRateConfig.variableRateSlope2MaxChange
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

  function _setGhoBorrowRateViaConfigurator(uint256 newBorrowRate) internal {
    IDefaultInterestRateStrategyV2.InterestRateData
      memory rateParams = IDefaultInterestRateStrategyV2.InterestRateData({
        optimalUsageRatio: 1_00,
        baseVariableBorrowRate: uint32(newBorrowRate),
        variableRateSlope1: 0,
        variableRateSlope2: 0
      });
    CONFIGURATOR.setReserveInterestRateData(address(GHO_TOKEN), abi.encode(rateParams));
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function _getGhoBorrowRate() internal view returns (uint256) {
    address currentInterestRateStrategy = POOL.getReserveInterestRateStrategyAddress(
      address(GHO_TOKEN)
    );
    return
      IDefaultInterestRateStrategyV2(currentInterestRateStrategy).getBaseVariableBorrowRate(
        address(GHO_TOKEN)
      ) / 1e23; // Convert to bps
  }

  function _getOptimalUsageRatio() internal view returns (uint256) {
    address currentInterestRateStrategy = POOL.getReserveInterestRateStrategyAddress(
      address(GHO_TOKEN)
    );
    return
      IDefaultInterestRateStrategyV2(currentInterestRateStrategy).getOptimalUsageRatio(
        address(GHO_TOKEN)
      ) / 1e23; // Convert to bps
  }

  function _getVariableRateSlope1() internal view returns (uint256) {
    address currentInterestRateStrategy = POOL.getReserveInterestRateStrategyAddress(
      address(GHO_TOKEN)
    );
    return
      IDefaultInterestRateStrategyV2(currentInterestRateStrategy).getVariableRateSlope1(
        address(GHO_TOKEN)
      ) / 1e23; // Convert to bps
  }
}

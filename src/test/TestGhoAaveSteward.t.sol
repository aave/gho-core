// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import {IGhoAaveSteward} from '../contracts/misc/interfaces/IGhoAaveSteward.sol';

contract TestGhoAaveSteward is TestGhoBase {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  function setUp() public {
    /// @dev Since block.timestamp starts at 0 this is a necessary condition (block.timestamp > `MINIMUM_DELAY`) for the timelocked contract methods to work.
    vm.warp(GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
  }

  function testConstructor() public {
    assertEq(GHO_AAVE_STEWARD.MINIMUM_DELAY(), MINIMUM_DELAY_V2);

    assertEq(GHO_AAVE_STEWARD.owner(), SHORT_EXECUTOR);
    assertEq(GHO_AAVE_STEWARD.POOL_ADDRESSES_PROVIDER(), address(PROVIDER));
    assertEq(GHO_AAVE_STEWARD.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(GHO_AAVE_STEWARD.FIXED_RATE_STRATEGY_FACTORY(), address(FIXED_RATE_STRATEGY_FACTORY));
    assertEq(GHO_AAVE_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);

    IGhoAaveSteward.GhoDebounce memory ghoTimelocks = GHO_AAVE_STEWARD.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowCapLastUpdate, 0);
  }

  function testRevertConstructorInvalidExecutor() public {
    vm.expectRevert('INVALID_OWNER');
    new GhoAaveSteward(address(0), address(0x002), address(0x003), address(0x004), address(0x005));
  }

  function testRevertConstructorInvalidAddressesProvider() public {
    vm.expectRevert('INVALID_ADDRESSES_PROVIDER');
    new GhoAaveSteward(address(0x001), address(0), address(0x003), address(0x004), address(0x005));
  }

  function testRevertConstructorInvalidGhoToken() public {
    vm.expectRevert('INVALID_GHO_TOKEN');
    new GhoAaveSteward(address(0x001), address(0x002), address(0), address(0x004), address(0x005));
  }

  function testRevertConstructorInvalidFixedRateStrategyFactory() public {
    vm.expectRevert('INVALID_FIXED_RATE_STRATEGY_FACTORY');
    new GhoAaveSteward(address(0x001), address(0x002), address(0x003), address(0), address(0x005));
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new GhoAaveSteward(address(0x001), address(0x002), address(0x003), address(0x004), address(0));
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

  function testRevertUpdateGhoBorrowCapIfValueMoreThanDouble() public {
    uint256 oldBorrowCap = 1e6;
    _setGhoBorrowCapViaConfigurator(oldBorrowCap);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_CAP_UPDATE');
    GHO_AAVE_STEWARD.updateGhoBorrowCap(oldBorrowCap * 2 + 1);
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
}

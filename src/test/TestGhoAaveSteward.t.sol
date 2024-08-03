// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import {IGhoAaveSteward} from '../contracts/misc/interfaces/IGhoAaveSteward.sol';

contract TestGhoAaveSteward is TestGhoBase {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  function setUp() public {
    // Deploy Gho Aave Steward
    MockConfigEngine engine = new MockConfigEngine();
    GHO_AAVE_STEWARD = new GhoAaveSteward(
      address(PROVIDER),
      address(AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER),
      address(engine),
      address(GHO_TOKEN),
      address(FIXED_RATE_STRATEGY_FACTORY),
      RISK_COUNCIL
    );

    /// @dev Since block.timestamp starts at 0 this is a necessary condition (block.timestamp > `MINIMUM_DELAY`) for the timelocked contract methods to work.
    vm.warp(GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
  }

  function testConstructor() public {
    assertEq(GHO_AAVE_STEWARD.MINIMUM_DELAY(), MINIMUM_DELAY_V2);

    assertEq(GHO_AAVE_STEWARD.POOL_ADDRESSES_PROVIDER(), address(PROVIDER));
    assertEq(
      GHO_AAVE_STEWARD.POOL_DATA_PROVIDER(),
      address(AaveV3Ethereum.AAVE_PROTOCOL_DATA_PROVIDER)
    );
    assertEq(GHO_AAVE_STEWARD.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(GHO_AAVE_STEWARD.FIXED_RATE_STRATEGY_FACTORY(), address(FIXED_RATE_STRATEGY_FACTORY));
    assertEq(GHO_AAVE_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);

    IGhoAaveSteward.GhoDebounce memory ghoTimelocks = GHO_AAVE_STEWARD.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowCapLastUpdate, 0);
  }

  function testRevertConstructorInvalidAddressesProvider() public {
    vm.expectRevert('INVALID_ADDRESSES_PROVIDER');
    new GhoAaveSteward(
      address(0),
      address(0x002),
      address(0x003),
      address(0x004),
      address(0x005),
      address(0x006)
    );
  }

  function testRevertConstructorInvalidDataProvider() public {
    vm.expectRevert('INVALID_DATA_PROVIDER');
    new GhoAaveSteward(
      address(0x001),
      address(0),
      address(0x003),
      address(0x004),
      address(0x005),
      address(0x006)
    );
  }

  function testRevertConstructorInvalidConfigEngine() public {
    vm.expectRevert('INVALID_CONFIG_ENGINE');
    new GhoAaveSteward(
      address(0x001),
      address(0x002),
      address(0),
      address(0x004),
      address(0x005),
      address(0x006)
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
      address(0x006)
    );
  }

  function testRevertConstructorInvalidFixedRateStrategyFactory() public {
    vm.expectRevert('INVALID_FIXED_RATE_STRATEGY_FACTORY');
    new GhoAaveSteward(
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
    new GhoAaveSteward(
      address(0x001),
      address(0x002),
      address(0x003),
      address(0x004),
      address(0x005),
      address(0)
    );
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

  function testRevertUpdateGhoSupplyCapIfValueMoreThanDouble() public {
    uint256 oldSupplyCap = 1e6;
    _setGhoSupplyCapViaConfigurator(oldSupplyCap);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_SUPPLY_CAP_UPDATE');
    GHO_AAVE_STEWARD.updateGhoSupplyCap(oldSupplyCap * 2 + 1);
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
}

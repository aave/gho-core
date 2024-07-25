// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import {IGhoAaveSteward} from '../contracts/misc/interfaces/IGhoAaveSteward.sol';

contract TestGhoAaveSteward is TestGhoBase {
  function setUp() public {
    /// @dev Since block.timestamp starts at 0 this is a necessary condition (block.timestamp > `MINIMUM_DELAY`) for the timelocked contract methods to work.
    vm.warp(GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);

    // Grant required roles
    GHO_TOKEN.grantRole(GHO_TOKEN_BUCKET_MANAGER_ROLE, address(GHO_AAVE_STEWARD));
  }

  function testConstructor() public {
    assertEq(GHO_AAVE_STEWARD.GHO_BORROW_RATE_CHANGE_MAX(), GHO_BORROW_RATE_CHANGE_MAX);
    assertEq(GHO_AAVE_STEWARD.GHO_BORROW_RATE_MAX(), GHO_BORROW_RATE_MAX);
    assertEq(GHO_AAVE_STEWARD.MINIMUM_DELAY(), MINIMUM_DELAY_V2);

    assertEq(GHO_AAVE_STEWARD.owner(), SHORT_EXECUTOR);
    assertEq(GHO_AAVE_STEWARD.POOL_ADDRESSES_PROVIDER(), address(PROVIDER));
    assertEq(GHO_AAVE_STEWARD.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(GHO_AAVE_STEWARD.FIXED_RATE_STRATEGY_FACTORY(), address(FIXED_RATE_STRATEGY_FACTORY));
    assertEq(GHO_AAVE_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);

    IGhoAaveSteward.GhoDebounce memory ghoTimelocks = GHO_AAVE_STEWARD.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowCapLastUpdate, 0);
    assertEq(ghoTimelocks.ghoBorrowRateLastUpdate, 0);
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
}

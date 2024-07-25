// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGhoCcipStewardArbitrum is TestGhoBase {
  function setUp() public {
    /// @dev Since block.timestamp starts at 0 this is a necessary condition (block.timestamp > `MINIMUM_DELAY`) for the timelocked contract methods to work.
    vm.warp(ARB_GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
  }

  function testConstructor() public {
    assertEq(ARB_GHO_AAVE_STEWARD.GHO_BORROW_RATE_CHANGE_MAX(), GHO_BORROW_RATE_CHANGE_MAX);
    assertEq(ARB_GHO_AAVE_STEWARD.GHO_BORROW_RATE_MAX(), GHO_BORROW_RATE_MAX);
    assertEq(ARB_GHO_AAVE_STEWARD.MINIMUM_DELAY(), MINIMUM_DELAY_V2);

    assertEq(ARB_GHO_AAVE_STEWARD.owner(), SHORT_EXECUTOR);
    assertEq(ARB_GHO_AAVE_STEWARD.POOL_ADDRESSES_PROVIDER(), address(PROVIDER));
    assertEq(ARB_GHO_AAVE_STEWARD.GHO_TOKEN(), address(GHO_TOKEN));
    assertEq(
      ARB_GHO_AAVE_STEWARD.FIXED_RATE_STRATEGY_FACTORY(),
      address(FIXED_RATE_STRATEGY_FACTORY)
    );
    assertEq(ARB_GHO_AAVE_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);

    IGhoAaveSteward.GhoDebounce memory ghoTimelocks = ARB_GHO_AAVE_STEWARD.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowCapLastUpdate, 0);
    assertEq(ghoTimelocks.ghoBorrowRateLastUpdate, 0);
  }

  function testUpdateGhoBorrowRateUpwards() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + 1;
    vm.prank(RISK_COUNCIL);
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateDownwards() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - 1;
    vm.prank(RISK_COUNCIL);
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateMaxValue() public {
    uint256 ghoBorrowRateMax = ARB_GHO_AAVE_STEWARD.GHO_BORROW_RATE_MAX();
    (, uint256 oldBorrowRate) = _setGhoBorrowRateViaConfigurator(ghoBorrowRateMax - 1);
    vm.prank(RISK_COUNCIL);
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(ghoBorrowRateMax);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, ghoBorrowRateMax);
  }

  function testUpdateGhoBorrowRateMaxIncrement() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + ARB_GHO_AAVE_STEWARD.GHO_BORROW_RATE_CHANGE_MAX();
    vm.prank(RISK_COUNCIL);
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateDecrement() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - 1;
    vm.prank(RISK_COUNCIL);
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testUpdateGhoBorrowRateMaxDecrement() public {
    vm.startPrank(RISK_COUNCIL);

    // set a high borrow rate
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(ARB_GHO_AAVE_STEWARD.GHO_BORROW_RATE_CHANGE_MAX() + 1);
    vm.warp(block.timestamp + ARB_GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);

    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - ARB_GHO_AAVE_STEWARD.GHO_BORROW_RATE_CHANGE_MAX();
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);

    vm.stopPrank();
  }

  function testUpdateGhoBorrowRateTimelock() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(oldBorrowRate + 1);
    IGhoAaveSteward.GhoDebounce memory ghoTimelocks = ARB_GHO_AAVE_STEWARD.getGhoTimelocks();
    assertEq(ghoTimelocks.ghoBorrowRateLastUpdate, block.timestamp);
  }

  function testUpdateGhoBorrowRateAfterTimelock() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    vm.prank(RISK_COUNCIL);
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(oldBorrowRate + 1);
    skip(ARB_GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);
    uint256 newBorrowRate = oldBorrowRate + 2;
    vm.prank(RISK_COUNCIL);
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(newBorrowRate);
    uint256 currentBorrowRate = _getGhoBorrowRate();
    assertEq(currentBorrowRate, newBorrowRate);
  }

  function testRevertUpdateGhoBorrowRateIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(0.07e4);
  }

  function testRevertUpdateGhoBorrowRateIfUpdatedTooSoon() public {
    address oldInterestStrategy = POOL.getReserveInterestRateStrategyAddress(address(GHO_TOKEN));
    uint256 oldBorrowRate = GhoInterestRateStrategy(oldInterestStrategy)
      .getBaseVariableBorrowRate();
    vm.prank(RISK_COUNCIL);
    uint256 newBorrowRate = oldBorrowRate + 1;
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(newBorrowRate);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(newBorrowRate);
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
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(oldBorrowRate + 1);
  }

  function testRevertUpdateGhoBorrowRateIfValueMoreThanMax() public {
    uint256 maxGhoBorrowRate = ARB_GHO_AAVE_STEWARD.GHO_BORROW_RATE_MAX();
    _setGhoBorrowRateViaConfigurator(maxGhoBorrowRate);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('BORROW_RATE_HIGHER_THAN_MAX');
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(maxGhoBorrowRate + 1);
  }

  function testRevertUpdateGhoBorrowRateIfMaxExceededUpwards() public {
    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate + ARB_GHO_AAVE_STEWARD.GHO_BORROW_RATE_CHANGE_MAX() + 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(newBorrowRate);
  }

  function testRevertUpdateGhoBorrowRateIfMaxExceededDownwards() public {
    vm.startPrank(RISK_COUNCIL);

    // set a high borrow rate
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(ARB_GHO_AAVE_STEWARD.GHO_BORROW_RATE_CHANGE_MAX() + 1);
    vm.warp(block.timestamp + ARB_GHO_AAVE_STEWARD.MINIMUM_DELAY() + 1);

    uint256 oldBorrowRate = _getGhoBorrowRate();
    uint256 newBorrowRate = oldBorrowRate - ARB_GHO_AAVE_STEWARD.GHO_BORROW_RATE_CHANGE_MAX() - 1;
    vm.expectRevert('INVALID_BORROW_RATE_UPDATE');
    ARB_GHO_AAVE_STEWARD.updateGhoBorrowRate(newBorrowRate);

    vm.stopPrank();
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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import {IGhoGsmSteward} from '../contracts/misc/interfaces/IGhoGsmSteward.sol';

contract TestGhoGsmSteward is TestGhoBase {
  function setUp() public {
    // Deploy Gho GSM Steward
    GSM_FEE_STRATEGY_FACTORY = new GsmFeeStrategyFactory();
    GHO_GSM_STEWARD = new GhoGsmSteward(address(GSM_FEE_STRATEGY_FACTORY), RISK_COUNCIL);

    /// @dev Since block.timestamp starts at 0 this is a necessary condition (block.timestamp > `MINIMUM_DELAY`) for the timelocked contract methods to work.
    vm.warp(GHO_GSM_STEWARD.MINIMUM_DELAY() + 1);

    // Grant required roles
    GHO_GSM.grantRole(GSM_CONFIGURATOR_ROLE, address(GHO_GSM_STEWARD));
  }

  function testConstructor() public {
    assertEq(GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX(), GSM_FEE_RATE_CHANGE_MAX);
    assertEq(GHO_GSM_STEWARD.MINIMUM_DELAY(), MINIMUM_DELAY_V2);

    assertEq(GHO_GSM_STEWARD.GSM_FEE_STRATEGY_FACTORY(), address(GSM_FEE_STRATEGY_FACTORY));
    assertEq(GHO_GSM_STEWARD.RISK_COUNCIL(), RISK_COUNCIL);

    address[] memory gsmFeeStrategies = GHO_GSM_STEWARD.getGsmFeeStrategies();
    assertEq(gsmFeeStrategies.length, 0);
  }

  function testRevertConstructorInvalidGsmFeeStrategyFactory() public {
    vm.expectRevert('INVALID_GSM_FEE_STRATEGY_FACTORY');
    new GhoGsmSteward(address(0), address(0x002));
  }

  function testRevertConstructorInvalidRiskCouncil() public {
    vm.expectRevert('INVALID_RISK_COUNCIL');
    new GhoGsmSteward(address(0x001), address(0));
  }

  function testUpdateGsmExposureCapUpwards() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    uint128 newExposureCap = oldExposureCap + 1;
    GHO_GSM_STEWARD.updateGsmExposureCap(address(GHO_GSM), newExposureCap);
    uint128 currentExposureCap = GHO_GSM.getExposureCap();
    assertEq(currentExposureCap, newExposureCap);
  }

  function testUpdateGsmExposureCapDownwards() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    uint128 newExposureCap = oldExposureCap - 1;
    GHO_GSM_STEWARD.updateGsmExposureCap(address(GHO_GSM), newExposureCap);
    uint128 currentExposureCap = GHO_GSM.getExposureCap();
    assertEq(currentExposureCap, newExposureCap);
  }

  function testUpdateGsmExposureCapMaxIncrease() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    uint128 newExposureCap = oldExposureCap * 2;
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmExposureCap(address(GHO_GSM), newExposureCap);
    uint128 currentExposureCap = GHO_GSM.getExposureCap();
    assertEq(currentExposureCap, newExposureCap);
  }

  function testUpdateGsmExposureCapMaxDecrease() public {
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmExposureCap(address(GHO_GSM), 0);
    uint128 currentExposureCap = GHO_GSM.getExposureCap();
    assertEq(currentExposureCap, 0);
  }

  function testUpdateGsmExposureCapTimelock() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmExposureCap(address(GHO_GSM), oldExposureCap + 1);
    IGhoGsmSteward.GsmDebounce memory timelocks = GHO_GSM_STEWARD.getGsmTimelocks(address(GHO_GSM));
    assertEq(timelocks.gsmExposureCapLastUpdated, block.timestamp);
  }

  function testUpdateGsmExposureCapAfterTimelock() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmExposureCap(address(GHO_GSM), oldExposureCap + 1);
    skip(GHO_GSM_STEWARD.MINIMUM_DELAY() + 1);
    uint128 newExposureCap = oldExposureCap + 2;
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmExposureCap(address(GHO_GSM), newExposureCap);
    uint128 currentExposureCap = GHO_GSM.getExposureCap();
    assertEq(currentExposureCap, newExposureCap);
  }

  function testRevertUpdateGsmExposureCapIfUnauthorized() public {
    vm.expectRevert('INVALID_CALLER');
    vm.prank(ALICE);
    GHO_GSM_STEWARD.updateGsmExposureCap(address(GHO_GSM), 50_000_000e18);
  }

  function testRevertUpdateGsmExposureCapIfTooSoon() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmExposureCap(address(GHO_GSM), oldExposureCap + 1);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_GSM_STEWARD.updateGsmExposureCap(address(GHO_GSM), oldExposureCap + 2);
  }

  function testRevertUpdateGsmExposureCapIfValueMoreThanDouble() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_EXPOSURE_CAP_UPDATE');
    GHO_GSM_STEWARD.updateGsmExposureCap(address(GHO_GSM), oldExposureCap * 2 + 1);
  }

  function testRevertUpdateGsmExposureCapIfStewardLostConfiguratorRole() public {
    uint128 oldExposureCap = GHO_GSM.getExposureCap();
    GHO_GSM.revokeRole(GSM_CONFIGURATOR_ROLE, address(GHO_GSM_STEWARD));
    vm.expectRevert(
      AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, address(GHO_GSM_STEWARD))
    );
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmExposureCap(address(GHO_GSM), oldExposureCap + 1);
  }

  function testUpdateGsmBuySellFeesBuyFeeUpwards() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    assertEq(newBuyFee, buyFee + 1);
  }

  function testUpdateGsmBuySellFeesBuyFeeDownwards() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee - 1, sellFee);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    assertEq(newBuyFee, buyFee - 1);
  }

  function testUpdateGsmBuySellFeesBuyFeeMax() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    uint256 maxFeeUpdate = GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX();
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + maxFeeUpdate, sellFee);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    assertEq(newBuyFee, buyFee + maxFeeUpdate);
  }

  function testUpdateGsmBuySellFeesBuyFeeMin() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    uint256 maxFeeUpdate = GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX();
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee - maxFeeUpdate, sellFee);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    assertEq(newBuyFee, buyFee - maxFeeUpdate);
  }

  function testUpdateGsmBuySellFeesSellFeeUpwards() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee, sellFee + 1);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newSellFee = IGsmFeeStrategy(newStrategy).getSellFee(1e4);
    assertEq(newSellFee, sellFee + 1);
  }

  function testUpdateGsmBuySellFeesSellFeeDownwards() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee, sellFee - 1);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newSellFee = IGsmFeeStrategy(newStrategy).getSellFee(1e4);
    assertEq(newSellFee, sellFee - 1);
  }

  function testUpdateGsmBuySellFeesSellFeeMax() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    uint256 maxFeeUpdate = GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX();
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee, sellFee + maxFeeUpdate);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newSellFee = IGsmFeeStrategy(newStrategy).getSellFee(1e4);
    assertEq(newSellFee, sellFee + maxFeeUpdate);
  }

  function testUpdateGsmBuySellFeesSellFeeMin() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    uint256 maxFeeUpdate = GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX();
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee, sellFee - maxFeeUpdate);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newSellFee = IGsmFeeStrategy(newStrategy).getSellFee(1e4);
    assertEq(newSellFee, sellFee - maxFeeUpdate);
  }

  function testUpdateGsmBuySellFeesBothFeesUpwards() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    uint256 newSellFee = IGsmFeeStrategy(newStrategy).getSellFee(1e4);
    assertEq(newBuyFee, buyFee + 1);
    assertEq(newSellFee, sellFee + 1);
  }

  function testUpdateGsmBuySellFeesBothFeesDownwards() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee - 1, sellFee - 1);
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    uint256 newSellFee = IGsmFeeStrategy(newStrategy).getSellFee(1e4);
    assertEq(newBuyFee, buyFee - 1);
    assertEq(newSellFee, sellFee - 1);
  }

  function testUpdateGsmBuySellFeesBothFeesMax() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    uint256 maxFeeUpdate = GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX();
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(
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

  function testUpdateGsmBuySellFeesBothFeesMin() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    uint256 maxFeeUpdate = GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX();
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(
      address(GHO_GSM),
      buyFee - maxFeeUpdate,
      sellFee - maxFeeUpdate
    );
    address newStrategy = GHO_GSM.getFeeStrategy();
    uint256 newBuyFee = IGsmFeeStrategy(newStrategy).getBuyFee(1e4);
    uint256 newSellFee = IGsmFeeStrategy(newStrategy).getSellFee(1e4);
    assertEq(newBuyFee, buyFee - maxFeeUpdate);
    assertEq(newSellFee, sellFee - maxFeeUpdate);
  }

  function testUpdateGsmBuySellFeesTimelock() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    IGhoGsmSteward.GsmDebounce memory timelocks = GHO_GSM_STEWARD.getGsmTimelocks(address(GHO_GSM));
    assertEq(timelocks.gsmFeeStrategyLastUpdated, block.timestamp);
  }

  function testUpdateGsmBuySellFeesAfterTimelock() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    skip(GHO_GSM_STEWARD.MINIMUM_DELAY() + 1);
    uint256 newBuyFee = buyFee + 2;
    uint256 newSellFee = sellFee + 2;
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), newBuyFee, newSellFee);
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
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    address[] memory cachedStrategies = GHO_GSM_STEWARD.getGsmFeeStrategies();
    assertEq(cachedStrategies.length, 1);
    address newStrategy = GHO_GSM.getFeeStrategy();
    assertEq(newStrategy, cachedStrategies[0]);
  }

  function testUpdateGsmBuySellFeesSameStrategy() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    address oldStrategy = GHO_GSM.getFeeStrategy();
    skip(GHO_GSM_STEWARD.MINIMUM_DELAY() + 1);
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    address[] memory cachedStrategies = GHO_GSM_STEWARD.getGsmFeeStrategies();
    assertEq(cachedStrategies.length, 1);
    address newStrategy = GHO_GSM.getFeeStrategy();
    assertEq(oldStrategy, newStrategy);
  }

  function testRevertUpdateGsmBuySellFeesIfUnauthorized() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_CALLER');
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), 0.01e4, 0.01e4);
  }

  function testRevertUpdateGsmBuySellFeesIfTooSoon() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('DEBOUNCE_NOT_RESPECTED');
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + 2, sellFee + 2);
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
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
  }

  function testRevertUpdateGsmBuySellFeesIfBuyFeeMoreThanMax() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 maxFeeUpdate = GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUY_FEE_UPDATE');
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + maxFeeUpdate + 1, sellFee);
  }

  function testRevertUpdateGsmBuySellFeesIfBuyFeeLessThanMin() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 maxFeeUpdate = GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUY_FEE_UPDATE');
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee - maxFeeUpdate - 1, sellFee);
  }

  function testRevertUpdateGsmBuySellFeesIfSellFeeMoreThanMax() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 maxFeeUpdate = GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_SELL_FEE_UPDATE');
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee, sellFee + maxFeeUpdate + 1);
  }

  function testRevertUpdateGsmBuySellFeesIfSellFeeLessThanMin() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 maxFeeUpdate = GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_SELL_FEE_UPDATE');
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee, sellFee - maxFeeUpdate - 1);
  }

  function testRevertUpdateGsmBuySellFeesIfBothMoreThanMax() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 maxFeeUpdate = GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUY_FEE_UPDATE');
    GHO_GSM_STEWARD.updateGsmBuySellFees(
      address(GHO_GSM),
      buyFee + maxFeeUpdate + 1,
      sellFee + maxFeeUpdate + 1
    );
  }

  function testRevertUpdateGsmBuySellFeesIfBothLessThanMin() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 maxFeeUpdate = GHO_GSM_STEWARD.GSM_FEE_RATE_CHANGE_MAX();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert('INVALID_BUY_FEE_UPDATE');
    GHO_GSM_STEWARD.updateGsmBuySellFees(
      address(GHO_GSM),
      buyFee - maxFeeUpdate - 1,
      sellFee - maxFeeUpdate - 1
    );
  }

  function testRevertUpdateGsmBuySellFeesIfStewardLostConfiguratorRole() public {
    address feeStrategy = GHO_GSM.getFeeStrategy();
    uint256 buyFee = IGsmFeeStrategy(feeStrategy).getBuyFee(1e4);
    uint256 sellFee = IGsmFeeStrategy(feeStrategy).getSellFee(1e4);
    GHO_GSM.revokeRole(GSM_CONFIGURATOR_ROLE, address(GHO_GSM_STEWARD));
    vm.expectRevert(
      AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, address(GHO_GSM_STEWARD))
    );
    vm.prank(RISK_COUNCIL);
    GHO_GSM_STEWARD.updateGsmBuySellFees(address(GHO_GSM), buyFee + 1, sellFee + 1);
  }
}

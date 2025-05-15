// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmFullFlow is TestGhoBase {
  function testGsmFull() public {
    OwnableFacilitator facilitator = new OwnableFacilitator(address(this), address(GHO_TOKEN));
    GHO_TOKEN.addFacilitator(address(facilitator), 'OwnableFacilitatorFlow', DEFAULT_CAPACITY);

    GhoReserve reserve = new GhoReserve(address(this), address(GHO_TOKEN));
    reserve.initialize(address(this));

    Gsm gsm = new Gsm(
      address(GHO_TOKEN),
      address(USDC_TOKEN),
      address(GHO_GSM_FIXED_PRICE_STRATEGY)
    );
    gsm.initialize(address(this), TREASURY, DEFAULT_GSM_USDC_EXPOSURE, address(reserve));

    reserve.setEntityLimit(address(gsm), 5_000_000 ether);

    uint256 mintAmount = 10_000_000 ether;
    assertEq(GHO_TOKEN.balanceOf(address(reserve)), 0);
    (uint256 capacity, uint256 level) = GHO_TOKEN.getFacilitatorBucket(address(facilitator));

    assertEq(capacity, DEFAULT_CAPACITY, 'Unexpected initial capacity');
    assertEq(level, 0, 'Unexpected initial level');

    facilitator.mint(address(reserve), mintAmount);

    (, level) = GHO_TOKEN.getFacilitatorBucket(address(facilitator));

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), mintAmount, 'Unexpected balanceOf GHO');
    assertEq(level, mintAmount, 'Unexpected level after mint');

    // Use zero fees for simplicity
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(gsm), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(gsm));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, 0);
    (uint256 assetAmount, uint256 ghoBought) = gsm.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(ghoBought, DEFAULT_GSM_GHO_AMOUNT, 'Unexpected GHO amount bought');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount sold');
    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), DEFAULT_GSM_GHO_AMOUNT, 'Unexpected final GHO balance');
    assertEq(gsm.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
    assertEq(ghoBought, gsm.getUsedGho(), 'Unexpected amount of used GHO');

    (uint256 limit, uint256 used) = reserve.getUsage(address(gsm));

    assertEq(
      limit - used,
      reserve.getLimit(address(gsm)) - ghoBought,
      'Unexpected amount of available capacity'
    );

    // Buy assets as another user
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(gsm), DEFAULT_GSM_GHO_AMOUNT);
    vm.expectEmit(true, true, true, true, address(gsm));
    emit BuyAsset(BOB, BOB, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, 0);
    (uint256 assetAmountBought, uint256 ghoSold) = gsm.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    assertEq(ghoSold, DEFAULT_GSM_GHO_AMOUNT, 'Unexpected GHO amount sold');
    assertEq(assetAmountBought, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount bought');
    assertEq(USDC_TOKEN.balanceOf(BOB), DEFAULT_GSM_USDC_AMOUNT, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), DEFAULT_GSM_GHO_AMOUNT, 'Unexpected final GHO balance');
    assertEq(gsm.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
    assertEq(0, gsm.getUsedGho(), 'Unexpected amount of used GHO');

    (limit, used) = reserve.getUsage(address(gsm));

    assertEq(
      limit - used,
      reserve.getLimit(address(gsm)),
      'Unexpected amount of available capacity'
    );

    reserve.transfer(address(facilitator), GHO_TOKEN.balanceOf(address(reserve)));

    assertEq(GHO_TOKEN.balanceOf(address(reserve)), 0);
    facilitator.burn(mintAmount);

    (, level) = GHO_TOKEN.getFacilitatorBucket(address(facilitator));

    assertEq(level, 0, 'Unexpected level after burn');

    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorRemoved(address(facilitator));
    GHO_TOKEN.removeFacilitator(address(facilitator));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmSampleLiquidator is TestGhoBase {
  function testSeize() public {
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit Seized(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), TREASURY, 0, 0);
    GHO_GSM_LAST_RESORT_LIQUIDATOR.triggerSeize(address(GHO_GSM));
  }

  function testRevertSeizeNotAuthorized() public {
    vm.expectRevert(OwnableErrorsLib.CALLER_NOT_OWNER());
    vm.prank(ALICE);
    GHO_GSM_LAST_RESORT_LIQUIDATOR.triggerSeize(address(GHO_GSM));
  }

  function testRevertSeizeAlreadySeized() public {
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit Seized(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), TREASURY, 0, 0);
    GHO_GSM_LAST_RESORT_LIQUIDATOR.triggerSeize(address(GHO_GSM));

    vm.expectRevert('GSM_SEIZED');
    GHO_GSM_LAST_RESORT_LIQUIDATOR.triggerSeize(address(GHO_GSM));
  }

  function testBurnAfterSeize() public {
    // Mint GHO in the GSM
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    // Seize the GSM
    uint256 seizedAmount = GHO_GSM_LAST_RESORT_LIQUIDATOR.triggerSeize(address(GHO_GSM));
    assertEq(seizedAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected seize amount returned');

    // Mint the current bucket level
    (, uint256 bucketLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM));
    assertGt(bucketLevel, 0, 'Unexpected 0 minted GHO');
    ghoFaucet(address(this), bucketLevel);

    GHO_TOKEN.approve(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), bucketLevel);
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit BurnAfterSeize(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), bucketLevel, 0);
    uint256 burnAmount = GHO_GSM_LAST_RESORT_LIQUIDATOR.triggerBurnAfterSeize(
      address(GHO_GSM),
      bucketLevel
    );
    assertEq(burnAmount, bucketLevel, 'Unexpected burn amount returned');
  }

  function testBurnMoreThanMintedAfterSeize() public {
    // Mint GHO in the GSM
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    // Seize the GSM
    uint256 seizedAmount = GHO_GSM_LAST_RESORT_LIQUIDATOR.triggerSeize(address(GHO_GSM));
    assertEq(seizedAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected seize amount returned');

    // Mint the current bucket level + 1, to have more GHO than necessary
    (, uint256 bucketLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM));
    assertGt(bucketLevel, 0, 'Unexpected 0 minted GHO');
    ghoFaucet(address(this), bucketLevel + 1);

    // Attempt to burn more than what was minted, leaving 1 GHO left-over and burning the bucketLevel
    GHO_TOKEN.approve(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), bucketLevel + 1);
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit BurnAfterSeize(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), bucketLevel, 0);
    uint256 burnAmount = GHO_GSM_LAST_RESORT_LIQUIDATOR.triggerBurnAfterSeize(
      address(GHO_GSM),
      bucketLevel + 1
    );
    assertEq(burnAmount, bucketLevel, 'Unexpected burn amount returned');
    assertEq(GHO_TOKEN.balanceOf(address(this)), 1, 'Unexpected final GHO amount');
  }
}

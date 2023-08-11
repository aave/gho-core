// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGSMSampleLastResortLiquidator is TestGhoBase {
  function testSeize() public {
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit Seized(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), ALICE, 0, 0);
    GHO_GSM_LAST_RESORT_LIQUIDATOR.triggerSeize(address(GHO_GSM), ALICE);
  }

  function testRevertSeizeNotAuthorized() public {
    vm.prank(ALICE);
    vm.expectRevert('Ownable: caller is not the owner');
    GHO_GSM_LAST_RESORT_LIQUIDATOR.triggerSeize(address(GHO_GSM), ALICE);
  }

  function testRevertSeizeAlreadySeized() public {
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit Seized(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), ALICE, 0, 0);
    GHO_GSM_LAST_RESORT_LIQUIDATOR.triggerSeize(address(GHO_GSM), ALICE);

    vm.expectRevert('GSM_SEIZED_SWAPS_DISABLED');
    GHO_GSM_LAST_RESORT_LIQUIDATOR.triggerSeize(address(GHO_GSM), ALICE);
  }
}

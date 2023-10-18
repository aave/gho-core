// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import {OracleSwapFreezer} from '../contracts/facilitators/gsm/swapFreezer/OracleSwapFreezer.sol';

contract TestGsmOracleSwapFreezer is TestGhoBase {
  OracleSwapFreezer swapFreezer;
  OracleSwapFreezer.Bound defaultFreezeBound = OracleSwapFreezer.Bound(97000000, 103000000);
  OracleSwapFreezer.Bound defaultUnfreezeBound = OracleSwapFreezer.Bound(99000000, 101000000);

  function setUp() public {
    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), 100000000);
    swapFreezer = new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      defaultFreezeBound,
      defaultUnfreezeBound,
      true
    );
    GHO_GSM.grantRole(GSM_SWAP_FREEZER_ROLE, address(swapFreezer));
  }

  function testRevertConstructorInvalidUnderlying() public {
    vm.expectRevert('UNDERLYING_ASSET_MISMATCH');
    new OracleSwapFreezer(
      GHO_GSM,
      address(0),
      IPoolAddressesProvider(address(PROVIDER)),
      defaultFreezeBound,
      defaultUnfreezeBound,
      true
    );
  }

  function testConstructorInvalidUnfreezeWhileFreezeNotAllowed() public {
    OracleSwapFreezer.Bound memory unfreezeBound = OracleSwapFreezer.Bound(0, type(uint128).max);

    // Ensure bound check fails if allowing unfreezing, as expected
    vm.expectRevert('BOUNDS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      defaultFreezeBound,
      unfreezeBound,
      true
    );

    // No revert expected when not allowing unfreezing
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      defaultFreezeBound,
      unfreezeBound,
      false
    );
  }

  function testRevertConstructorInvalidBounds() public {
    // Case 1: Freeze upper bound less than or equal to lower bound
    OracleSwapFreezer.Bound memory freezeBound = OracleSwapFreezer.Bound(
      defaultFreezeBound.lowerBound,
      defaultFreezeBound.lowerBound
    );
    vm.expectRevert('BOUNDS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      freezeBound,
      defaultUnfreezeBound,
      true
    );

    // Case 2: Unfreeze upper bound less than or equal to lower bound
    OracleSwapFreezer.Bound memory unfreezeBound = OracleSwapFreezer.Bound(
      defaultUnfreezeBound.upperBound,
      defaultUnfreezeBound.upperBound
    );
    vm.expectRevert('BOUNDS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      defaultFreezeBound,
      unfreezeBound,
      true
    );

    // Case 3: Freeze lower bound is greater than or equal to unfreeze lower bound
    freezeBound = OracleSwapFreezer.Bound(
      defaultUnfreezeBound.lowerBound,
      defaultFreezeBound.upperBound
    );
    vm.expectRevert('BOUNDS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      freezeBound,
      defaultUnfreezeBound,
      true
    );

    // Case 4: Unfreeze upper bound is greater than or equal to freeze upper bound
    unfreezeBound = OracleSwapFreezer.Bound(
      defaultUnfreezeBound.lowerBound,
      defaultFreezeBound.upperBound
    );
    vm.expectRevert('BOUNDS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      defaultFreezeBound,
      unfreezeBound,
      true
    );
  }

  function testCheckUpkeepCanFreeze() public {
    (bool canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, false, 'Unexpected initial upkeep state');

    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), defaultFreezeBound.lowerBound);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price == freeze lower bound');

    assertLt(1, defaultFreezeBound.lowerBound, '1 not less than freeze lower bound');
    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), 1);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price < freeze lower bound');

    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), defaultFreezeBound.upperBound);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price == freeze upper bound');

    assertGt(
      type(uint128).max,
      defaultFreezeBound.upperBound,
      'uint128.max not greater than freeze upper bound'
    );
    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), type(uint128).max);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price > freeze upper bound');
  }

  function testCheckUpkeepCannotFreezeWhenOracleZero() public {
    (bool canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, false, 'Unexpected initial upkeep state');

    assertLt(0, defaultFreezeBound.lowerBound, '0 not less than freeze lower bound');
    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), 0);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, false, 'Unexpected upkeep state when oracle price is zero');
  }

  function testCheckUpkeepCanUnfreeze() public {
    // Freeze the GSM and set the asset price to 1 wei
    vm.prank(address(GHO_GSM_SWAP_FREEZER));
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit SwapFreeze(address(GHO_GSM_SWAP_FREEZER), true);
    GHO_GSM.setSwapFreeze(true);
    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), 1);

    (bool canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, false, 'Unexpected initial upkeep state');

    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), defaultUnfreezeBound.lowerBound);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price >= unfreeze lower bound');

    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), defaultUnfreezeBound.upperBound);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price <= unfreeze upper bound');

    PRICE_ORACLE.setAssetPrice(
      address(USDC_TOKEN),
      (defaultUnfreezeBound.lowerBound + defaultUnfreezeBound.upperBound) / 2
    );
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price in unfreeze bound range');
  }

  function testCheckUpkeepCannotUnfreeze() public {
    OracleSwapFreezer swapFreezerWithoutUnfreeze = new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      defaultFreezeBound,
      defaultUnfreezeBound,
      false
    );

    // Freeze the GSM
    vm.prank(address(GHO_GSM_SWAP_FREEZER));
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit SwapFreeze(address(GHO_GSM_SWAP_FREEZER), true);
    GHO_GSM.setSwapFreeze(true);

    (bool canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state for default freezer');

    (canPerformUpkeep, ) = swapFreezerWithoutUnfreeze.checkUpkeep('');
    assertEq(canPerformUpkeep, false, 'Unexpected upkeep state for no-unfreeze freezer');
  }

  function testPerformUpkeepCanFreeze() public {
    (bool canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, false, 'Unexpected initial upkeep state');
    assertEq(GHO_GSM.getIsFrozen(), false, 'Unexpected initial freeze state for GSM');

    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), defaultFreezeBound.lowerBound);
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit SwapFreeze(address(swapFreezer), true);
    swapFreezer.performUpkeep('');

    assertEq(GHO_GSM.getIsFrozen(), true, 'Unexpected final freeze state for GSM');
  }

  function testPerformUpkeepCanUnfreeze() public {
    // Freeze the GSM and set price to 1 wei
    vm.prank(address(GHO_GSM_SWAP_FREEZER));
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit SwapFreeze(address(GHO_GSM_SWAP_FREEZER), true);
    GHO_GSM.setSwapFreeze(true);
    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), 1);

    (bool canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, false, 'Unexpected initial upkeep state');
    assertEq(GHO_GSM.getIsFrozen(), true, 'Unexpected initial freeze state for GSM');

    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), defaultUnfreezeBound.lowerBound);
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit SwapFreeze(address(swapFreezer), false);
    swapFreezer.performUpkeep('');

    assertEq(GHO_GSM.getIsFrozen(), false, 'Unexpected final freeze state for GSM');
  }

  function testGetCanUnfreeze() public {
    assertEq(swapFreezer.getCanUnfreeze(), true, 'Unexpected initial unfreeze state');
    swapFreezer = new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      defaultFreezeBound,
      defaultUnfreezeBound,
      false
    );
    assertEq(swapFreezer.getCanUnfreeze(), false, 'Unexpected final unfreeze state');
  }

  function testGetUnfreezeBoundZeroWhenDisallowUnfreeze() public {
    OracleSwapFreezer.Bound memory unfreezeBound = swapFreezer.getUnfreezeBound();
    assertEq(
      unfreezeBound.lowerBound,
      defaultUnfreezeBound.lowerBound,
      'Unexpected initial unfreeze lower bound'
    );
    assertEq(
      unfreezeBound.upperBound,
      defaultUnfreezeBound.upperBound,
      'Unexpected initial unfreeze upper bound'
    );
    swapFreezer = new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      defaultFreezeBound,
      defaultUnfreezeBound,
      false
    );
    unfreezeBound = swapFreezer.getUnfreezeBound();
    assertEq(unfreezeBound.lowerBound, 0, 'Unexpected final unfreeze lower bound');
    assertEq(unfreezeBound.upperBound, 0, 'Unexpected final unfreeze upper bound');
  }
}

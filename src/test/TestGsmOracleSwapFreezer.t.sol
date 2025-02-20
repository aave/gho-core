// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';
import {OracleSwapFreezer} from '../contracts/facilitators/gsm/swapFreezer/OracleSwapFreezer.sol';

contract TestGsmOracleSwapFreezer is TestGhoBase {
  OracleSwapFreezer swapFreezer;
  uint128 constant DEFAULT_FREEZE_LOWER_BOUND = 0.97e8;
  uint128 constant DEFAULT_FREEZE_UPPER_BOUND = 1.03e8;
  uint128 constant DEFAULT_UNFREEZE_LOWER_BOUND = 0.99e8;
  uint128 constant DEFAULT_UNFREEZE_UPPER_BOUND = 1.01e8;

  function setUp() public {
    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), 1e8);
    swapFreezer = new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      DEFAULT_FREEZE_LOWER_BOUND,
      DEFAULT_FREEZE_UPPER_BOUND,
      DEFAULT_UNFREEZE_LOWER_BOUND,
      DEFAULT_UNFREEZE_UPPER_BOUND,
      true
    );
    GHO_GSM.grantRole(GSM_SWAP_FREEZER_ROLE, address(swapFreezer));
  }

  function testRevertConstructorInvalidZeroAddress() public {
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(0),
      IPoolAddressesProvider(address(PROVIDER)),
      DEFAULT_FREEZE_LOWER_BOUND,
      DEFAULT_FREEZE_UPPER_BOUND,
      DEFAULT_UNFREEZE_LOWER_BOUND,
      DEFAULT_UNFREEZE_UPPER_BOUND,
      true
    );
  }

  function testConstructorInvalidUnfreezeWhileFreezeNotAllowed() public {
    uint128 unfreezeLowerBound = 1;
    uint128 unfreezeUpperBound = type(uint128).max;

    // Ensure bound check fails if allowing unfreezing, as expected
    vm.expectRevert('BOUNDS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      DEFAULT_FREEZE_LOWER_BOUND,
      DEFAULT_FREEZE_UPPER_BOUND,
      unfreezeLowerBound,
      unfreezeUpperBound,
      true
    );

    // Revert expected when non-zero unfreeze lower bound
    unfreezeUpperBound = 0;
    vm.expectRevert('BOUNDS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      DEFAULT_FREEZE_LOWER_BOUND,
      DEFAULT_FREEZE_UPPER_BOUND,
      unfreezeLowerBound,
      unfreezeUpperBound,
      false
    );

    // Revert expected when non-zero unfreeze upper bound
    unfreezeLowerBound = 0;
    unfreezeUpperBound = type(uint128).max;
    vm.expectRevert('BOUNDS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      DEFAULT_FREEZE_LOWER_BOUND,
      DEFAULT_FREEZE_UPPER_BOUND,
      unfreezeLowerBound,
      unfreezeUpperBound,
      false
    );

    // No revert expected with 0 unfreeze lower/upper bound
    unfreezeLowerBound = 0;
    unfreezeUpperBound = 0;
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      DEFAULT_FREEZE_LOWER_BOUND,
      DEFAULT_FREEZE_UPPER_BOUND,
      unfreezeLowerBound,
      unfreezeUpperBound,
      false
    );
  }

  function testRevertConstructorInvalidBounds() public {
    // Case 1: Freeze upper bound less than or equal to lower bound
    uint128 freezeLowerBound = DEFAULT_FREEZE_LOWER_BOUND;
    uint128 freezeUpperBound = DEFAULT_FREEZE_LOWER_BOUND;
    vm.expectRevert('BOUNDS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      freezeLowerBound,
      freezeUpperBound,
      DEFAULT_UNFREEZE_LOWER_BOUND,
      DEFAULT_UNFREEZE_UPPER_BOUND,
      true
    );

    // Case 2: Unfreeze upper bound less than or equal to lower bound
    uint128 unfreezeLowerBound = DEFAULT_UNFREEZE_UPPER_BOUND;
    uint128 unfreezeUpperBound = DEFAULT_UNFREEZE_UPPER_BOUND;
    vm.expectRevert('BOUNDS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      DEFAULT_FREEZE_LOWER_BOUND,
      DEFAULT_FREEZE_UPPER_BOUND,
      unfreezeLowerBound,
      unfreezeUpperBound,
      true
    );

    // Case 3: Freeze lower bound is greater than or equal to unfreeze lower bound
    freezeLowerBound = DEFAULT_UNFREEZE_LOWER_BOUND;
    freezeUpperBound = DEFAULT_FREEZE_UPPER_BOUND;
    vm.expectRevert('BOUNDS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      freezeLowerBound,
      freezeUpperBound,
      DEFAULT_UNFREEZE_LOWER_BOUND,
      DEFAULT_UNFREEZE_UPPER_BOUND,
      true
    );

    // Case 4: Unfreeze upper bound is greater than or equal to freeze upper bound
    unfreezeLowerBound = DEFAULT_UNFREEZE_LOWER_BOUND;
    unfreezeUpperBound = DEFAULT_FREEZE_UPPER_BOUND;
    vm.expectRevert('BOUNDS_NOT_VALID');
    new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      DEFAULT_FREEZE_LOWER_BOUND,
      DEFAULT_FREEZE_UPPER_BOUND,
      unfreezeLowerBound,
      unfreezeUpperBound,
      true
    );
  }

  function testCheckUpkeepCanFreeze() public {
    (bool canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, false, 'Unexpected initial upkeep state');

    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), DEFAULT_FREEZE_LOWER_BOUND);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price == freeze lower bound');

    assertLt(1, DEFAULT_FREEZE_LOWER_BOUND, '1 not less than freeze lower bound');
    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), 1);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price < freeze lower bound');

    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), DEFAULT_FREEZE_UPPER_BOUND);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price == freeze upper bound');

    assertGt(
      type(uint128).max,
      DEFAULT_FREEZE_UPPER_BOUND,
      'uint128.max not greater than freeze upper bound'
    );
    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), type(uint128).max);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price > freeze upper bound');
  }

  function testCheckUpkeepCannotFreezeWhenOracleZero() public {
    (bool canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, false, 'Unexpected initial upkeep state');

    assertLt(0, DEFAULT_FREEZE_LOWER_BOUND, '0 not less than freeze lower bound');
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

    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), DEFAULT_UNFREEZE_LOWER_BOUND);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price >= unfreeze lower bound');

    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), DEFAULT_UNFREEZE_UPPER_BOUND);
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price <= unfreeze upper bound');

    PRICE_ORACLE.setAssetPrice(
      address(USDC_TOKEN),
      (DEFAULT_UNFREEZE_LOWER_BOUND + DEFAULT_UNFREEZE_UPPER_BOUND) / 2
    );
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected upkeep state after price in unfreeze bound range');
  }

  function testCheckUpkeepCannotUnfreeze() public {
    OracleSwapFreezer swapFreezerWithoutUnfreeze = new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      DEFAULT_FREEZE_LOWER_BOUND,
      DEFAULT_FREEZE_UPPER_BOUND,
      0,
      0,
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

  function testCheckUpkeepCannotUnfreezeWhenSeized() public {
    // Set oracle price to a value allowing a freeze
    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), DEFAULT_FREEZE_LOWER_BOUND);
    (bool canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected initial upkeep state for default freezer');

    // Seize the GSM
    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit Seized(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), TREASURY, 0, 0);
    GHO_GSM.seize();

    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, false, 'Unexpected upkeep state post-seize');
  }

  function testPerformUpkeepCanFreeze() public {
    (bool canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, false, 'Unexpected initial upkeep state');
    assertEq(GHO_GSM.getIsFrozen(), false, 'Unexpected initial freeze state for GSM');

    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), DEFAULT_FREEZE_LOWER_BOUND);
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

    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), DEFAULT_UNFREEZE_LOWER_BOUND);
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit SwapFreeze(address(swapFreezer), false);
    swapFreezer.performUpkeep('');

    assertEq(GHO_GSM.getIsFrozen(), false, 'Unexpected final freeze state for GSM');
  }

  function testCheckUpkeepNoSwapFreezeRole() public {
    // Move price outside freeze range
    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), DEFAULT_FREEZE_LOWER_BOUND - 1);
    (bool canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, true, 'Unexpected initial upkeep state');

    // Revoke SwapFreezer role
    GHO_GSM.revokeRole(GSM_SWAP_FREEZER_ROLE, address(swapFreezer));

    // Upkeep shouldn't be possible
    (canPerformUpkeep, ) = swapFreezer.checkUpkeep('');
    assertEq(canPerformUpkeep, false, 'Unexpected upkeep state');
    // Do not revert, it's a no-op execution
    swapFreezer.performUpkeep('');
  }

  function testGetCanUnfreeze() public {
    assertEq(swapFreezer.getCanUnfreeze(), true, 'Unexpected initial unfreeze state');
    swapFreezer = new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      DEFAULT_FREEZE_LOWER_BOUND,
      DEFAULT_FREEZE_UPPER_BOUND,
      0,
      0,
      false
    );
    assertEq(swapFreezer.getCanUnfreeze(), false, 'Unexpected final unfreeze state');
  }

  function testFuzzUpkeepConsistency(uint256 assetPrice, bool grantRole) public {
    PRICE_ORACLE.setAssetPrice(address(USDC_TOKEN), assetPrice);
    OracleSwapFreezer agent = new OracleSwapFreezer(
      GHO_GSM,
      address(USDC_TOKEN),
      IPoolAddressesProvider(address(PROVIDER)),
      DEFAULT_FREEZE_LOWER_BOUND,
      DEFAULT_FREEZE_UPPER_BOUND,
      DEFAULT_UNFREEZE_LOWER_BOUND,
      DEFAULT_UNFREEZE_UPPER_BOUND,
      true
    );
    if (grantRole) {
      GHO_GSM.grantRole(GSM_SWAP_FREEZER_ROLE, address(agent));
    }

    // If canPerformUpkeep, there must be a state change
    bool freezeState = GHO_GSM.getIsFrozen();
    (bool canPerformUpkeep, ) = agent.checkUpkeep('');

    agent.performUpkeep('');
    if (canPerformUpkeep) {
      // state change
      assertEq(freezeState, !GHO_GSM.getIsFrozen(), 'no state change after performUpkeep');
    } else {
      // no state change
      assertEq(freezeState, GHO_GSM.getIsFrozen(), 'state change after performUpkeep');
    }
  }
}

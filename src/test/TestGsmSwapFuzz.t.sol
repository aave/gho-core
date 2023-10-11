// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmSwapFuzz is TestGhoBase {
  using PercentageMath for uint256;
  using PercentageMath for uint128;

  /**
   * @dev Checks that passing an amount higher than 2*128-1 (`maxUint128`) to a swap function reverts
   */
  function testFuzzSwapAmountAbove128(
    uint8 underlyingDecimals,
    uint256 amount,
    uint8 buyFeeBps,
    uint8 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 26));
    buyFeeBps = uint8(bound(buyFeeBps, 0, 10000 - 1));
    sellFeeBps = uint8(bound(sellFeeBps, 0, 10000 - 1));
    amount = bound(amount, 1, type(uint128).max) + type(uint128).max; // avoiding a bug in forge-std where bound will revert

    TestnetERC20 mockToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(mockToken),
      underlyingDecimals // decimals
    );
    Gsm mockGsm = new Gsm(address(GHO_TOKEN), address(mockToken), address(newPriceStrategy));
    mockGsm.initialize(ALICE, TREASURY, type(uint128).max);
    GHO_TOKEN.addFacilitator(address(mockGsm), 'Test GSM', type(uint128).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(uint256(buyFeeBps), uint256(sellFeeBps));
      GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    }

    (uint256 ghoBought, , , ) = mockGsm.getGhoAmountForSellAsset(amount);
    vm.assume(ghoBought > type(uint128).max);

    vm.startPrank(FAUCET);
    mockToken.mint(FAUCET, amount);
    mockToken.approve(address(mockGsm), amount);
    vm.expectRevert();
    mockGsm.sellAsset(amount, ALICE);
    vm.stopPrank();
  }

  /**
   * @dev Tests to ensure a revert when the GSM holds the maximum amount of asset possible and a user attempts to buy
   * 1 more unit of the asset than is available
   */
  function testFuzzBuyAmountAboveMaximum(
    uint8 underlyingDecimals,
    uint8 buyFeeBps,
    uint8 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 26));
    buyFeeBps = uint8(bound(buyFeeBps, 0, 10000 - 1));
    sellFeeBps = uint8(bound(sellFeeBps, 0, 10000 - 1));

    TestnetERC20 mockToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(mockToken),
      underlyingDecimals // decimals
    );
    Gsm mockGsm = new Gsm(address(GHO_TOKEN), address(mockToken), address(newPriceStrategy));
    mockGsm.initialize(ALICE, TREASURY, type(uint128).max);
    GHO_TOKEN.addFacilitator(address(mockGsm), 'Test GSM', type(uint128).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(uint256(buyFeeBps), uint256(sellFeeBps));
      GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    }

    uint256 amount = newPriceStrategy.getGhoPriceInAsset(type(uint128).max, false);
    if (amount > type(uint128).max) {
      amount = type(uint128).max;
    }

    vm.startPrank(FAUCET);
    mockToken.mint(FAUCET, amount);
    mockToken.approve(address(mockGsm), amount);
    mockGsm.sellAsset(amount, ALICE);
    vm.stopPrank();

    ghoFaucet(BOB, type(uint128).max);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(mockGsm), type(uint128).max);
    vm.expectRevert();
    mockGsm.buyAsset(amount + 1, BOB);
    vm.stopPrank();
  }

  /**
   * @dev Checks behaviour of getGhoAmountForSellAsset
   */
  function testFuzzGetGhoAmountForSellAsset(
    uint8 underlyingDecimals,
    uint256 amount,
    uint8 buyFeeBps,
    uint8 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 26));
    buyFeeBps = uint8(bound(buyFeeBps, 0, 10000 - 1));
    sellFeeBps = uint8(bound(sellFeeBps, 0, 10000 - 1));
    amount = bound(amount, 1, type(uint128).max - 1);

    TestnetERC20 mockToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(mockToken),
      underlyingDecimals // decimals
    );
    Gsm mockGsm = new Gsm(address(GHO_TOKEN), address(mockToken), address(newPriceStrategy));
    mockGsm.initialize(ALICE, TREASURY, type(uint128).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(uint256(buyFeeBps), uint256(sellFeeBps));
      GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    }

    (uint256 exactAssetAmount, uint256 ghoBought, uint256 grossAmount, uint256 fee) = mockGsm
      .getGhoAmountForSellAsset(amount);
    assertTrue(exactAssetAmount <= amount, 'maximum asset amount exceeded');
    assertTrue(ghoBought <= grossAmount, 'gross amount lower than ghoBought');

    // In case of 0 sellFee
    if (sellFeeBps == 0) {
      assertEq(grossAmount, ghoBought, 'unexpected gross amount');
      assertEq(fee, 0, 'unexpected fee');
    }
  }

  /**
   * @dev Checks behaviour of getGhoAmountForBuyAsset
   */
  function testFuzzGetGhoAmountForBuyAsset(
    uint8 underlyingDecimals,
    uint256 amount,
    uint8 buyFeeBps,
    uint8 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 26));
    buyFeeBps = uint8(bound(buyFeeBps, 0, 10000 - 1));
    sellFeeBps = uint8(bound(sellFeeBps, 0, 10000 - 1));
    amount = bound(amount, 1, type(uint128).max - 1);

    TestnetERC20 mockToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(mockToken),
      underlyingDecimals // decimals
    );
    Gsm mockGsm = new Gsm(address(GHO_TOKEN), address(mockToken), address(newPriceStrategy));
    mockGsm.initialize(ALICE, TREASURY, type(uint128).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(uint256(buyFeeBps), uint256(sellFeeBps));
      GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    }

    (uint256 exactAssetAmount, uint256 ghoSold, uint256 grossAmount, uint256 fee) = mockGsm
      .getGhoAmountForBuyAsset(amount);
    assertTrue(exactAssetAmount >= amount, 'minimum asset amount not reached');
    assertTrue(ghoSold <= grossAmount, 'gross amount lower than ghoSold');

    // In case of 0 buyFee
    if (buyFeeBps == 0) {
      assertEq(grossAmount, ghoSold, 'unexpected gross amount');
      assertEq(fee, 0, 'unexpected fee');
    }
  }

  /**
   * @dev Checks behaviour of getAssetAmountForSellAsset
   */
  function testFuzzGetAssetAmountForSellAsset(
    uint8 underlyingDecimals,
    uint256 amount,
    uint8 buyFeeBps,
    uint8 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 26));
    buyFeeBps = uint8(bound(buyFeeBps, 0, 10000 - 1));
    sellFeeBps = uint8(bound(sellFeeBps, 0, 10000 - 1));
    amount = bound(amount, 1, type(uint128).max - 1);

    TestnetERC20 mockToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(mockToken),
      underlyingDecimals // decimals
    );
    Gsm mockGsm = new Gsm(address(GHO_TOKEN), address(mockToken), address(newPriceStrategy));
    mockGsm.initialize(ALICE, TREASURY, type(uint128).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(uint256(buyFeeBps), uint256(sellFeeBps));
      GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    }

    (, uint256 ghoBought, uint256 grossAmount, uint256 fee) = mockGsm.getAssetAmountForSellAsset(
      amount
    );
    assertTrue(ghoBought > 0, 'unexpected 0 value for ghoBought');
    assertTrue(ghoBought >= amount, 'minimum gho amount not reached');
    assertTrue(ghoBought <= grossAmount, 'gross amount lower than ghoBought');

    // In case of 0 sellFee
    if (sellFeeBps == 0) {
      assertEq(grossAmount, ghoBought, 'unexpected gross amount');
      assertEq(fee, 0, 'unexpected fee');
    }
  }

  /**
   * @dev Checks behaviour of getAssetAmountForBuyAsset
   */
  function testFuzzGetAssetAmountForBuyAsset(
    uint8 underlyingDecimals,
    uint256 amount,
    uint8 buyFeeBps,
    uint8 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 26));
    buyFeeBps = uint8(bound(buyFeeBps, 0, 10000 - 1));
    sellFeeBps = uint8(bound(sellFeeBps, 0, 10000 - 1));
    amount = bound(amount, 1, type(uint128).max - 1);

    TestnetERC20 mockToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(mockToken),
      underlyingDecimals // decimals
    );
    Gsm mockGsm = new Gsm(address(GHO_TOKEN), address(mockToken), address(newPriceStrategy));
    mockGsm.initialize(ALICE, TREASURY, type(uint128).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(uint256(buyFeeBps), uint256(sellFeeBps));
      GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    }

    (, uint256 ghoSold, uint256 grossAmount, uint256 fee) = mockGsm.getAssetAmountForBuyAsset(
      amount
    );
    assertTrue(ghoSold <= amount, 'maximum gho amount exceeded');
    assertTrue(ghoSold <= grossAmount, 'gross amount lower than ghoSold');

    // In case of 0 buyFee
    if (buyFeeBps == 0) {
      assertEq(grossAmount, ghoSold, 'unexpected gross amount');
      assertEq(fee, 0, 'unexpected fee');
    }
  }

  /**
   * @dev Checks the recalculation procedure of the amount in _sellAsset function
   */
  function testFuzzSellRecalculation(
    uint8 underlyingDecimals,
    uint256 assetAmount,
    uint8 buyFeeBps,
    uint8 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 26));
    buyFeeBps = uint8(bound(buyFeeBps, 0, 10000 - 1));
    sellFeeBps = uint8(bound(sellFeeBps, 0, 10000 - 1));
    assetAmount = bound(assetAmount, 1, type(uint128).max - 1);

    TestnetERC20 mockToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(mockToken),
      underlyingDecimals // decimals
    );
    Gsm mockGsm = new Gsm(address(GHO_TOKEN), address(mockToken), address(newPriceStrategy));
    mockGsm.initialize(ALICE, TREASURY, uint128(assetAmount));

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(uint256(buyFeeBps), uint256(sellFeeBps));
      GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    }

    // First, calculate the GHO amount to buy
    (, uint256 ghoBought, , ) = mockGsm.getGhoAmountForSellAsset(assetAmount);
    // Second, recalculate the asset amount required to sell
    (uint256 amount, , uint256 grossAmount1, uint256 fee1) = mockGsm.getAssetAmountForSellAsset(
      ghoBought
    );
    // Third, validate that the inverse function provides same values
    (, uint256 ghoBought2, uint256 grossAmount2, uint256 fee2) = mockGsm.getGhoAmountForSellAsset(
      amount
    );

    assertEq(ghoBought, ghoBought2, 'ghoBought do not match');
    assertEq(grossAmount1, grossAmount2, 'estimated gross amounts do not match');
    assertEq(fee1, fee2, 'estimated fees do not match');

    // In case of 0 sellFee
    if (sellFeeBps == 0) {
      assertEq(grossAmount1, ghoBought, 'unexpected grossAmount1 and ghoBought');
      assertEq(grossAmount2, ghoBought, 'unexpected grossAmount2 and ghoBought');
      assertEq(fee1, 0, 'expected fee1');
      assertEq(fee2, 0, 'expected fee2');
    }
  }

  /**
   * @dev Checks the recalculation procedure of the amount in _buyAsset function
   */
  function testFuzzBuyRecalculation(
    uint8 underlyingDecimals,
    uint256 assetAmount,
    uint8 buyFeeBps,
    uint8 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 26));
    buyFeeBps = uint8(bound(buyFeeBps, 0, 10000 - 1));
    sellFeeBps = uint8(bound(sellFeeBps, 0, 10000 - 1));
    assetAmount = bound(assetAmount, 1, type(uint128).max - 1);

    TestnetERC20 mockToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(mockToken),
      underlyingDecimals // decimals
    );
    Gsm mockGsm = new Gsm(address(GHO_TOKEN), address(mockToken), address(newPriceStrategy));
    mockGsm.initialize(ALICE, TREASURY, uint128(assetAmount));

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(uint256(buyFeeBps), uint256(sellFeeBps));
      GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    }

    // First, calculate the GHO amount to sell
    (, uint256 ghoSold, , ) = mockGsm.getGhoAmountForBuyAsset(assetAmount);
    // Second, recalculate the asset amount required to purchase
    (uint256 amount, uint256 exactGhoSold, uint256 grossAmount1, uint256 fee1) = mockGsm
      .getAssetAmountForBuyAsset(ghoSold);
    // Third, validate that the inverse function provides same values
    (uint256 exactAmount, uint256 ghoSold2, uint256 grossAmount2, uint256 fee2) = mockGsm
      .getGhoAmountForBuyAsset(amount);

    assertEq(exactAmount, amount, 'exact amount do not match');
    assertEq(ghoSold, exactGhoSold, 'exact ghoSold do not match');
    assertEq(ghoSold, ghoSold2, 'ghoSold do not match');
    assertEq(grossAmount1, grossAmount2, 'estimated gross amounts do not match');
    assertEq(fee1, fee2, 'estimated fees do not match');

    // In case of 0 buyFee
    if (buyFeeBps == 0) {
      assertEq(grossAmount1, ghoSold, 'unexpected grossAmount1 and ghoSold');
      assertEq(grossAmount2, ghoSold, 'unexpected grossAmount2 and ghoSold');
      assertEq(fee1, 0, 'expected fee1');
      assertEq(fee2, 0, 'expected fee2');
    }
  }

  /**
   * @dev Checks invariant between inverse functions to query amounts for the sell action: getGhoAmountForSellAsset
   * and getAssetAmountForSellAsset.
   */
  function testFuzzSellEstimation(
    uint8 underlyingDecimals,
    uint256 assetAmount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 26));
    buyFeeBps = uint8(bound(buyFeeBps, 0, 10000 - 1));
    sellFeeBps = uint8(bound(sellFeeBps, 0, 10000 - 1));
    assetAmount = bound(assetAmount, 1, type(uint64).max - 1);

    TestnetERC20 mockToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(mockToken),
      underlyingDecimals // decimals
    );
    Gsm mockGsm = new Gsm(address(GHO_TOKEN), address(mockToken), address(newPriceStrategy));
    mockGsm.initialize(ALICE, TREASURY, uint128(assetAmount));

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    }

    (uint256 exactAssetAmount, uint256 ghoBought, uint256 grossAmount1, uint256 fee1) = mockGsm
      .getGhoAmountForSellAsset(assetAmount);
    vm.assume(ghoBought > 0);
    (uint256 assetAmount2, uint256 exactGhoBought, uint256 grossAmount2, uint256 fee2) = mockGsm
      .getAssetAmountForSellAsset(ghoBought);

    assertTrue(
      assetAmount >= exactAssetAmount,
      'exact asset amount being used is higher than the amount passed'
    );
    assertTrue(
      assetAmount >= assetAmount2,
      'exact asset amount being used is higher than the amount passed'
    );
    assertEq(ghoBought, exactGhoBought, 'bought gho amount do not match');
    assertEq(exactAssetAmount, assetAmount2, 'given assetAmount and estimated do not match');
    assertEq(grossAmount1, grossAmount2, 'estimated gross amounts do not match');
    assertEq(fee1, fee2, 'estimated fees do not match');

    // In case of 0 sellFee
    if (sellFeeBps == 0) {
      assertEq(grossAmount1, ghoBought, 'unexpected grossAmount1 and ghoBought');
      assertEq(grossAmount2, ghoBought, 'unexpected grossAmount2 and ghoBought');
      assertEq(fee1, 0, 'expected fee1');
      assertEq(fee2, 0, 'expected fee2');
    }
  }

  /**
   * @dev Checks invariant between inverse functions to query amounts for the buy action: getGhoAmountForBuyAsset
   * and getAssetAmountForBuyAsset.
   */
  function testFuzzBuyEstimation(
    uint8 underlyingDecimals,
    uint256 assetAmount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 26));
    buyFeeBps = uint8(bound(buyFeeBps, 0, 10000 - 1));
    sellFeeBps = uint8(bound(sellFeeBps, 0, 10000 - 1));
    assetAmount = bound(assetAmount, 1, type(uint64).max - 1);

    TestnetERC20 mockToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(mockToken),
      underlyingDecimals // decimals
    );
    Gsm mockGsm = new Gsm(address(GHO_TOKEN), address(mockToken), address(newPriceStrategy));
    mockGsm.initialize(ALICE, TREASURY, uint128(assetAmount));

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    }

    (uint256 exactAssetAmount, uint256 ghoSold, uint256 grossAmount1, uint256 fee1) = mockGsm
      .getGhoAmountForBuyAsset(assetAmount);
    vm.assume(ghoSold > 0);
    (uint256 assetAmount2, uint256 exactGhoSold, uint256 grossAmount2, uint256 fee2) = mockGsm
      .getAssetAmountForBuyAsset(ghoSold);

    assertTrue(
      exactAssetAmount >= assetAmount,
      'exact asset amount being used is less than the amount passed'
    );
    assertTrue(
      assetAmount2 >= assetAmount,
      'exact asset amount being used is less than the amount passed'
    );
    assertEq(ghoSold, exactGhoSold, 'sold gho amount do not match');
    assertEq(exactAssetAmount, assetAmount2, 'given assetAmount and estimated do not match');
    assertEq(grossAmount1, grossAmount2, 'estimated gross amounts do not match');
    assertEq(fee1, fee2, 'estimated fees do not match');

    // In case of 0 buyFee
    if (buyFeeBps == 0) {
      assertEq(grossAmount1, ghoSold, 'unexpected grossAmount1 and ghoSold');
      assertEq(grossAmount2, ghoSold, 'unexpected grossAmount2 and ghoSold');
      assertEq(fee1, 0, 'expected fee1');
      assertEq(fee2, 0, 'expected fee2');
    }
  }

  struct TestFuzzSwapAssetWithEstimationVars {
    // estimation function 1
    uint256 estAssetAmount1;
    uint256 estGhoAmount1;
    uint256 estGrossAmount1;
    uint256 estFeeAmount1;
    // estimation function 2
    uint256 estAssetAmount2;
    uint256 estGhoAmount2;
    uint256 estGrossAmount2;
    uint256 estFeeAmount2;
    // swap function
    uint256 exactAssetAmount;
    uint256 exactGhoAmount;
  }

  /**
   * @dev Checks sellAsset is aligned with getAssetAmountForSellAsset and getGhoAmountForSellAsset
   */
  function testFuzzSellAssetWithEstimation(
    uint8 underlyingDecimals,
    uint256 assetAmount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    TestFuzzSwapAssetWithEstimationVars memory vars;

    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 26));
    buyFeeBps = uint8(bound(buyFeeBps, 0, 10000 - 1));
    sellFeeBps = uint8(bound(sellFeeBps, 0, 10000 - 1));
    assetAmount = bound(assetAmount, 1, type(uint64).max - 1);

    TestnetERC20 mockToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    vm.prank(FAUCET);
    mockToken.mint(ALICE, assetAmount);

    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(mockToken),
      underlyingDecimals // decimals
    );
    Gsm mockGsm = new Gsm(address(GHO_TOKEN), address(mockToken), address(newPriceStrategy));
    mockGsm.initialize(ALICE, TREASURY, uint128(assetAmount));
    GHO_TOKEN.addFacilitator(address(mockGsm), 'GSM TINY', type(uint128).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    }

    vm.startPrank(ALICE);
    mockToken.approve(address(mockGsm), type(uint256).max);

    uint256 userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 userAssetBefore = mockToken.balanceOf(ALICE);

    // Calculate GHO amount to purchase with given asset amount, bail if 0
    (, vars.estGhoAmount1, vars.estGrossAmount1, vars.estFeeAmount1) = mockGsm
      .getGhoAmountForSellAsset(assetAmount);
    vm.assume(vars.estGhoAmount1 > 0);

    (vars.exactAssetAmount, vars.exactGhoAmount) = mockGsm.sellAsset(assetAmount, ALICE);

    // Calculate asset amount needed for the amount of GHO required to buy
    (vars.estAssetAmount2, , vars.estGrossAmount2, vars.estFeeAmount2) = mockGsm
      .getAssetAmountForSellAsset(vars.exactGhoAmount);

    assertEq(
      userAssetBefore - mockToken.balanceOf(ALICE),
      vars.exactAssetAmount,
      'real assets sold are not equal to the exact amount'
    );
    assertTrue(
      userAssetBefore - mockToken.balanceOf(ALICE) <= assetAmount,
      'real assets sold are more than the input'
    );
    assertEq(
      GHO_TOKEN.balanceOf(ALICE) - userGhoBefore,
      vars.exactGhoAmount,
      'real gho bought does not match returned value'
    );
    assertEq(
      GHO_TOKEN.balanceOf(ALICE) - userGhoBefore,
      vars.estGhoAmount1,
      'real gho bought does not match estimated value'
    );
    assertEq(
      userAssetBefore - mockToken.balanceOf(ALICE),
      vars.estAssetAmount2,
      'real assets sold does not match estimated value'
    );

    assertEq(vars.estGrossAmount1, vars.estGrossAmount2, 'estimated gross amounts do not match');
    assertEq(vars.estFeeAmount1, vars.estFeeAmount2, 'estimated fees do not match');

    // In case of 0 sellFeeBps
    if (sellFeeBps == 0) {
      assertEq(vars.estGrossAmount1, vars.exactGhoAmount, 'unexpected grossAmount1 and ghoBought');
      assertEq(vars.estGrossAmount2, vars.exactGhoAmount, 'unexpected grossAmount2 and ghoBought');
      assertEq(vars.estFeeAmount1, 0, 'expected fee1');
      assertEq(vars.estFeeAmount2, 0, 'expected fee2');
    }

    vm.stopPrank();
  }

  /**
   * @dev Checks buyAsset is aligned with getAssetAmountForBuyAsset and getGhoAmountForBuyAsset
   */
  function testFuzzBuyAssetWithEstimation(
    uint8 underlyingDecimals,
    uint256 assetAmount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    TestFuzzSwapAssetWithEstimationVars memory vars;

    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 26));
    buyFeeBps = uint8(bound(buyFeeBps, 0, 10000 - 1));
    sellFeeBps = uint8(bound(sellFeeBps, 0, 10000 - 1));
    assetAmount = bound(assetAmount, 1, type(uint64).max - 1);

    TestnetERC20 mockToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    vm.prank(FAUCET);
    mockToken.mint(ALICE, assetAmount);

    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(mockToken),
      underlyingDecimals // decimals
    );
    Gsm mockGsm = new Gsm(address(GHO_TOKEN), address(mockToken), address(newPriceStrategy));
    mockGsm.initialize(ALICE, TREASURY, uint128(assetAmount));
    GHO_TOKEN.addFacilitator(address(mockGsm), 'GSM TINY', type(uint128).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      GHO_GSM_FIXED_FEE_STRATEGY = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      GHO_GSM.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    }

    {
      // Calculate GHO amount to purchase with given asset amount, bail if 0
      (, uint256 estGhoBought, , ) = mockGsm.getGhoAmountForSellAsset(assetAmount);
      vm.assume(estGhoBought > 0);

      vm.startPrank(ALICE);
      // Alice sells asset to the GSM, up to exposure cap
      mockToken.approve(address(mockGsm), type(uint256).max);
      GHO_TOKEN.approve(address(mockGsm), type(uint256).max);
      mockGsm.sellAsset(assetAmount, ALICE);

      // rough estimation of GHO funds needed for buyAsset
      (, estGhoBought, , ) = mockGsm.getGhoAmountForBuyAsset(assetAmount);
      vm.stopPrank();
      ghoFaucet(ALICE, estGhoBought * 20);
    }

    // buy all available liquidity
    uint256 assetToBuy = mockGsm.getAvailableLiquidity();

    vm.startPrank(ALICE);
    uint256 userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 userAssetBefore = mockToken.balanceOf(ALICE);

    // Calculate GHO amount to sell with given asset amount
    (, vars.estGhoAmount1, vars.estGhoAmount1, vars.estFeeAmount1) = mockGsm
      .getGhoAmountForBuyAsset(assetToBuy);

    userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    userAssetBefore = mockToken.balanceOf(ALICE);

    (vars.exactAssetAmount, vars.exactGhoAmount) = mockGsm.buyAsset(assetToBuy, ALICE);

    // Calculate asset amount can be bought for the amount of GHO available
    (vars.estAssetAmount2, , vars.estGhoAmount2, vars.estFeeAmount2) = mockGsm
      .getAssetAmountForBuyAsset(vars.exactGhoAmount);

    assertEq(
      mockToken.balanceOf(ALICE) - userAssetBefore,
      vars.exactAssetAmount,
      'real assets bought are not equal to the exact amount'
    );
    assertTrue(
      mockToken.balanceOf(ALICE) - userAssetBefore >= assetToBuy,
      'real assets bought are less than the input'
    );
    assertEq(
      mockToken.balanceOf(ALICE) - userAssetBefore,
      vars.estAssetAmount2,
      'real assets bought does not match estimated value'
    );
    assertEq(
      userGhoBefore - GHO_TOKEN.balanceOf(ALICE),
      vars.exactGhoAmount,
      'real gho sold does not match returned value'
    );
    assertEq(
      userGhoBefore - GHO_TOKEN.balanceOf(ALICE),
      vars.estGhoAmount1,
      'real gho sold does not match estimated value'
    );

    assertEq(vars.estGhoAmount1, vars.estGhoAmount2, 'estimated gross amounts do not match');
    assertEq(vars.estFeeAmount1, vars.estFeeAmount2, 'estimated fees do not match');

    // In case of 0 buyFeeBps
    if (buyFeeBps == 0) {
      assertEq(vars.estGhoAmount1, vars.exactGhoAmount, 'unexpected grossAmount1 and ghoSold');
      assertEq(vars.estGhoAmount2, vars.exactGhoAmount, 'unexpected grossAmount2 and ghoSold');
      assertEq(vars.estFeeAmount1, 0, 'expected fee1');
      assertEq(vars.estFeeAmount2, 0, 'expected fee2');
    }

    vm.stopPrank();
  }
}

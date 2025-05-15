// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

/**
 * @title TestGsmSwapFuzz
 * @dev Fuzzing tests for swap functions
 * @dev Bounds for priceRatio: [0.01e18, 100e18]
 * @dev Bounds for fees: [0, 5000]
 * @dev Bounds for underlyingDecimals: [5, 27]
 */
contract TestGsmSwapFuzz is TestGhoBase {
  using PercentageMath for uint256;
  using PercentageMath for uint128;

  struct TestFuzzSwapAssetVars {
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

  function _checkValidPrice(
    FixedPriceStrategy priceStrat,
    uint256 assetAmount,
    uint256 ghoAmount
  ) internal {
    assertApproxEqAbs(
      priceStrat.getAssetPriceInGho(assetAmount, false),
      ghoAmount,
      2,
      'price between asset and gho amounts is not valid _1'
    );

    assertApproxEqAbs(
      priceStrat.getAssetPriceInGho(assetAmount, true),
      ghoAmount,
      2,
      'price between asset and gho amounts is not valid _2'
    );

    assertApproxEqAbs(
      priceStrat.getGhoPriceInAsset(ghoAmount, false),
      assetAmount,
      2,
      'price between asset and gho amounts is not valid _3'
    );
    assertApproxEqAbs(
      priceStrat.getGhoPriceInAsset(ghoAmount, true),
      assetAmount,
      2,
      'price between asset and gho amounts is not valid _4'
    );
  }

  /**
   * @dev Check there is no way of making money by sell-buy actions
   */
  function testFuzzSellBuyNoArb(
    uint8 underlyingDecimals,
    uint256 priceRatio,
    uint256 assetAmount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    TestFuzzSwapAssetVars memory vars;

    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 27));
    buyFeeBps = bound(buyFeeBps, 0, 5000 - 1);
    sellFeeBps = bound(sellFeeBps, 0, 5000 - 1);
    priceRatio = bound(priceRatio, 0.01e18, 100e18);
    assetAmount = bound(assetAmount, 1, type(uint64).max - 1);

    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);

    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      priceRatio,
      address(newToken),
      underlyingDecimals // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, type(uint128).max, address(GHO_RESERVE));
    GHO_RESERVE.setEntityLimit(address(gsm), type(uint128).max);
    deal(address(GHO_TOKEN), address(GHO_RESERVE), type(uint256).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      gsm.updateFeeStrategy(address(newFeeStrategy));
    }

    // Strat estimation
    (, vars.estGhoAmount1, , ) = gsm.getGhoAmountForSellAsset(assetAmount);
    (vars.estAssetAmount2, , , ) = gsm.getAssetAmountForBuyAsset(vars.estGhoAmount1);
    assertLe(
      vars.estAssetAmount2,
      assetAmount,
      'getting more assetAmount than provided in estimation'
    );

    // Init GSM with some assets
    (, uint256 aux, , ) = gsm.getGhoAmountForSellAsset(assetAmount);
    vm.assume(aux > 0);
    vm.startPrank(FAUCET);
    newToken.mint(FAUCET, assetAmount);
    newToken.approve(address(gsm), type(uint256).max);
    gsm.sellAsset(assetAmount, FAUCET);
    vm.stopPrank();

    // Arb Strat estimation
    (, vars.estGhoAmount1, , ) = gsm.getGhoAmountForSellAsset(assetAmount);
    (vars.estAssetAmount2, , , ) = gsm.getAssetAmountForBuyAsset(vars.estGhoAmount1);
    assertLe(
      vars.estAssetAmount2,
      assetAmount,
      'getting more assetAmount than provided in estimation'
    );

    // Top up Alice
    vm.prank(FAUCET);
    newToken.mint(ALICE, assetAmount);

    // Arb Strat
    vm.startPrank(ALICE);
    uint256 aliceBalanceBefore = newToken.balanceOf(ALICE);
    newToken.approve(address(gsm), type(uint256).max);
    GHO_TOKEN.approve(address(gsm), type(uint256).max);

    (, vars.exactGhoAmount) = gsm.sellAsset(assetAmount, ALICE);
    (vars.estAssetAmount1, , , ) = gsm.getAssetAmountForBuyAsset(vars.exactGhoAmount);
    assertLe(
      vars.estAssetAmount1,
      assetAmount,
      'getting more assetAmount than provided in estimation'
    );
    vm.assume(vars.estAssetAmount1 > 0); // 0 value is a valid for the property to hold, but buyAsset op would fail
    (vars.exactAssetAmount, ) = gsm.buyAsset(vars.estAssetAmount1, ALICE);

    assertLe(vars.exactAssetAmount, assetAmount, 'getting more assetAmount than provided in swap');
    assertLe(newToken.balanceOf(ALICE), aliceBalanceBefore, 'asset balance more than before');
    vm.stopPrank();
  }

  /**
   * @dev It is possible to use values for price ratio that creates unbalance in the GSM, so all GHO cannot be burned.
   * e.g. With (1e16 + 1) priceRatio, a user gets 1e11 gho for selling 1 asset but gets 1 asset by selling 1e11+1 gho
   */
  function testFuzzPriceRatioRoundingUnbalance(
    uint8 underlyingDecimals,
    uint256 priceRatio,
    uint256 amount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 27));
    buyFeeBps = bound(buyFeeBps, 0, 5000 - 1);
    sellFeeBps = bound(sellFeeBps, 0, 5000 - 1);
    priceRatio = bound(priceRatio, 0.01e18, 100e18);
    amount = bound(amount, 1, type(uint128).max - 1);

    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      priceRatio,
      address(newToken),
      underlyingDecimals // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, type(uint128).max, address(GHO_RESERVE));

    // Get gho amount for selling assets
    (uint256 assetSold, , uint256 ghoMinted, ) = gsm.getGhoAmountForSellAsset(amount);
    (, , uint256 ghoToBurn, ) = gsm.getGhoAmountForBuyAsset(assetSold);

    // 1 unit of imprecision due to rounding
    assertTrue(ghoToBurn <= ghoMinted + 1, 'unexpected gsm unbalance');

    // Get amount of assets can be purchased based on minted GHO amount
    (, uint256 ghoAmount, , ) = gsm.getAssetAmountForBuyAsset(ghoMinted);
    assertTrue(ghoAmount <= ghoMinted);
  }

  /**
   * @dev Checks that passing an amount higher than 2*128-1 (`maxUint128`) to a swap function reverts
   */
  function testFuzzSwapAmountAbove128(
    uint8 underlyingDecimals,
    uint256 priceRatio,
    uint256 amount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 27));
    buyFeeBps = bound(buyFeeBps, 0, 5000 - 1);
    sellFeeBps = bound(sellFeeBps, 0, 5000 - 1);
    priceRatio = bound(priceRatio, 0.01e18, 100e18);
    amount = bound(amount, 1, type(uint128).max) + type(uint128).max; // avoiding a bug in forge-std where bound will revert

    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      priceRatio,
      address(newToken),
      underlyingDecimals // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, type(uint128).max, address(GHO_RESERVE));
    GHO_TOKEN.addFacilitator(address(gsm), 'Test GSM', type(uint128).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      gsm.updateFeeStrategy(address(newFeeStrategy));
    }

    (uint256 ghoBought, , , ) = gsm.getGhoAmountForSellAsset(amount);
    vm.assume(ghoBought > type(uint128).max);

    vm.startPrank(FAUCET);
    newToken.mint(FAUCET, amount);
    newToken.approve(address(gsm), amount);
    vm.expectRevert();
    gsm.sellAsset(amount, ALICE);
    vm.stopPrank();
  }

  /**
   * @dev Tests to ensure a revert when the GSM holds the maximum amount of asset possible and a user attempts to buy
   * 1 more unit of the asset than is available
   */
  function testFuzzBuyAmountAboveMaximum(
    uint8 underlyingDecimals,
    uint256 priceRatio,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 27));
    priceRatio = bound(priceRatio, 0.01e18, 100e18);
    buyFeeBps = bound(buyFeeBps, 0, 5000 - 1);
    sellFeeBps = bound(sellFeeBps, 0, 5000 - 1);

    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      priceRatio,
      address(newToken),
      underlyingDecimals // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, type(uint128).max, address(GHO_RESERVE));
    GHO_RESERVE.setEntityLimit(address(gsm), type(uint256).max);
    deal(address(GHO_TOKEN), address(GHO_RESERVE), type(uint256).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      gsm.updateFeeStrategy(address(newFeeStrategy));
    }

    uint256 amount = newPriceStrategy.getGhoPriceInAsset(type(uint128).max, false);
    if (amount > type(uint128).max) {
      amount = type(uint128).max;
    }

    vm.startPrank(FAUCET);
    newToken.mint(FAUCET, amount);
    newToken.approve(address(gsm), amount);
    gsm.sellAsset(amount, ALICE);
    vm.stopPrank();

    ghoFaucet(BOB, type(uint128).max);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(gsm), type(uint128).max);
    vm.expectRevert();
    gsm.buyAsset(amount + 1, BOB);
    vm.stopPrank();
  }

  /**
   * @dev Checks behaviour of getGhoAmountForSellAsset
   */
  function testFuzzGetGhoAmountForSellAsset(
    uint8 underlyingDecimals,
    uint256 priceRatio,
    uint256 amount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 27));
    buyFeeBps = bound(buyFeeBps, 0, 5000 - 1);
    sellFeeBps = bound(sellFeeBps, 0, 5000 - 1);
    priceRatio = bound(priceRatio, 0.01e18, 100e18);
    amount = bound(amount, 1, type(uint128).max - 1);

    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      priceRatio,
      address(newToken),
      underlyingDecimals // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, type(uint128).max, address(GHO_RESERVE));
    GHO_RESERVE.setEntityLimit(address(gsm), type(uint256).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      gsm.updateFeeStrategy(address(newFeeStrategy));
    }

    (uint256 exactAssetAmount, uint256 ghoBought, uint256 grossAmount, uint256 fee) = gsm
      .getGhoAmountForSellAsset(amount);
    assertTrue(exactAssetAmount <= amount, 'maximum asset amount exceeded');
    assertTrue(ghoBought <= grossAmount, 'gross amount lower than ghoBought');
    _checkValidPrice(newPriceStrategy, exactAssetAmount, grossAmount);

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
    uint256 priceRatio,
    uint256 amount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 27));
    buyFeeBps = bound(buyFeeBps, 0, 5000 - 1);
    sellFeeBps = bound(sellFeeBps, 0, 5000 - 1);
    priceRatio = bound(priceRatio, 0.01e18, 100e18);
    amount = bound(amount, 1, type(uint128).max - 1);

    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      priceRatio,
      address(newToken),
      underlyingDecimals // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, type(uint128).max, address(GHO_RESERVE));
    GHO_RESERVE.setEntityLimit(address(gsm), type(uint256).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      gsm.updateFeeStrategy(address(newFeeStrategy));
    }

    (uint256 exactAssetAmount, uint256 ghoSold, uint256 grossAmount, uint256 fee) = gsm
      .getGhoAmountForBuyAsset(amount);
    assertTrue(exactAssetAmount >= amount, 'minimum asset amount not reached');
    assertTrue(ghoSold >= grossAmount, 'gross amount lower than ghoSold');
    _checkValidPrice(newPriceStrategy, exactAssetAmount, grossAmount);

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
    uint256 priceRatio,
    uint256 amount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 27));
    buyFeeBps = bound(buyFeeBps, 0, 5000 - 1);
    sellFeeBps = bound(sellFeeBps, 0, 5000 - 1);
    priceRatio = bound(priceRatio, 0.01e18, 100e18);
    amount = bound(amount, 1, type(uint128).max - 1);

    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      priceRatio,
      address(newToken),
      underlyingDecimals // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, type(uint128).max, address(GHO_RESERVE));
    GHO_RESERVE.setEntityLimit(address(gsm), type(uint256).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      gsm.updateFeeStrategy(address(newFeeStrategy));
    }

    (uint256 exactAssetAmount, uint256 ghoBought, uint256 grossAmount, uint256 fee) = gsm
      .getAssetAmountForSellAsset(amount);
    assertTrue(ghoBought > 0, 'unexpected 0 value for ghoBought');
    assertTrue(ghoBought >= amount, 'minimum gho amount not reached');
    assertTrue(ghoBought <= grossAmount, 'gross amount lower than ghoBought');
    _checkValidPrice(newPriceStrategy, exactAssetAmount, grossAmount);

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
    uint256 priceRatio,
    uint256 amount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 27));
    buyFeeBps = bound(buyFeeBps, 0, 5000 - 1);
    sellFeeBps = bound(sellFeeBps, 0, 5000 - 1);
    priceRatio = bound(priceRatio, 0.01e18, 100e18);
    amount = bound(amount, 1, type(uint128).max - 1);

    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      priceRatio,
      address(newToken),
      underlyingDecimals // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, type(uint128).max, address(GHO_RESERVE));

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      gsm.updateFeeStrategy(address(newFeeStrategy));
    }

    (uint256 exactAssetAmount, uint256 ghoSold, uint256 grossAmount, uint256 fee) = gsm
      .getAssetAmountForBuyAsset(amount);
    assertTrue(ghoSold <= amount, 'maximum gho amount exceeded');
    assertTrue(ghoSold >= grossAmount, 'gross amount lower than ghoSold');
    _checkValidPrice(newPriceStrategy, exactAssetAmount, grossAmount);

    // In case of 0 buyFee
    if (buyFeeBps == 0) {
      assertEq(grossAmount, ghoSold, 'unexpected gross amount');
      assertEq(fee, 0, 'unexpected fee');
    }
  }

  /**
   * @dev Checks invariant between inverse functions to query amounts for the sell action: getGhoAmountForSellAsset
   * and getAssetAmountForSellAsset.
   */
  function testFuzzSellEstimation(
    uint8 underlyingDecimals,
    uint256 priceRatio,
    uint256 assetAmount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    TestFuzzSwapAssetVars memory vars;

    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 27));
    buyFeeBps = bound(buyFeeBps, 0, 5000 - 1);
    sellFeeBps = bound(sellFeeBps, 0, 5000 - 1);
    priceRatio = bound(priceRatio, 0.01e18, 100e18);
    assetAmount = bound(assetAmount, 1, type(uint64).max - 1);

    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      priceRatio,
      address(newToken),
      underlyingDecimals // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, uint128(assetAmount), address(GHO_RESERVE));

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      gsm.updateFeeStrategy(address(newFeeStrategy));
    }

    (vars.estAssetAmount1, vars.estGhoAmount1, vars.estGrossAmount1, vars.estFeeAmount1) = gsm
      .getGhoAmountForSellAsset(assetAmount);
    vm.assume(vars.estGhoAmount1 > 0);
    (vars.estAssetAmount2, vars.estGhoAmount2, vars.estGrossAmount2, vars.estFeeAmount2) = gsm
      .getAssetAmountForSellAsset(vars.estGhoAmount1);

    assertTrue(
      assetAmount >= vars.estAssetAmount1,
      'exact asset amount being used is higher than the amount passed'
    );
    assertTrue(
      assetAmount >= vars.estAssetAmount2,
      'exact asset amount being used is higher than the amount passed'
    );
    assertEq(vars.estGhoAmount1, vars.estGhoAmount2, 'bought gho amount do not match');
    assertEq(
      vars.estAssetAmount1,
      vars.estAssetAmount2,
      'given assetAmount and estimated do not match'
    );
    // 1 wei precision error
    assertApproxEqAbs(
      vars.estGrossAmount1,
      vars.estGrossAmount2,
      1,
      'estimated gross amounts do not match'
    );
    assertApproxEqAbs(vars.estFeeAmount1, vars.estFeeAmount2, 1, 'estimated fees do not match');

    // In case of 0 sellFee
    if (sellFeeBps == 0) {
      assertEq(vars.estGrossAmount1, vars.estGhoAmount1, 'unexpected grossAmount1 and ghoBought');
      assertEq(vars.estGrossAmount2, vars.estGhoAmount1, 'unexpected grossAmount2 and ghoBought');
      assertEq(vars.estFeeAmount1, 0, 'expected fee1');
      assertEq(vars.estFeeAmount2, 0, 'expected fee2');
    }
  }

  /**
   * @dev Checks invariant between inverse functions to query amounts for the buy action: getGhoAmountForBuyAsset
   * and getAssetAmountForBuyAsset.
   */
  function testFuzzBuyEstimation(
    uint8 underlyingDecimals,
    uint256 priceRatio,
    uint256 assetAmount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    TestFuzzSwapAssetVars memory vars;

    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 27));
    buyFeeBps = bound(buyFeeBps, 0, 5000 - 1);
    sellFeeBps = bound(sellFeeBps, 0, 5000 - 1);
    priceRatio = bound(priceRatio, 0.01e18, 100e18);
    assetAmount = bound(assetAmount, 1, type(uint64).max - 1);

    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      priceRatio,
      address(newToken),
      underlyingDecimals // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, uint128(assetAmount), address(GHO_RESERVE));

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      gsm.updateFeeStrategy(address(newFeeStrategy));
    }

    (vars.estAssetAmount1, vars.estGhoAmount1, vars.estGrossAmount1, vars.estFeeAmount1) = gsm
      .getGhoAmountForBuyAsset(assetAmount);
    vm.assume(vars.estGhoAmount1 > 0);
    (vars.estAssetAmount2, vars.estGhoAmount2, vars.estGrossAmount2, vars.estFeeAmount2) = gsm
      .getAssetAmountForBuyAsset(vars.estGhoAmount1);

    assertTrue(
      vars.estAssetAmount1 >= assetAmount,
      'exact asset amount being used is less than the amount passed'
    );
    assertTrue(
      vars.estAssetAmount2 >= assetAmount,
      'exact asset amount being used is less than the amount passed'
    );
    assertEq(vars.estGhoAmount1, vars.estGhoAmount2, 'sold gho amount do not match');
    assertEq(
      vars.estAssetAmount1,
      vars.estAssetAmount2,
      'given assetAmount and estimated do not match'
    );
    assertEq(vars.estGrossAmount1, vars.estGrossAmount2, 'estimated gross amounts do not match');
    assertEq(vars.estFeeAmount1, vars.estFeeAmount2, 'estimated fees do not match');

    // In case of 0 buyFee
    if (buyFeeBps == 0) {
      assertEq(vars.estGrossAmount1, vars.estGhoAmount1, 'unexpected grossAmount1 and ghoSold');
      assertEq(vars.estGrossAmount2, vars.estGhoAmount1, 'unexpected grossAmount2 and ghoSold');
      assertEq(vars.estFeeAmount1, 0, 'expected fee1');
      assertEq(vars.estFeeAmount2, 0, 'expected fee2');
    }
  }

  /**
   * @dev Checks sellAsset is aligned with getAssetAmountForSellAsset and getGhoAmountForSellAsset
   */
  function testFuzzSellAssetWithEstimation(
    uint8 underlyingDecimals,
    uint256 priceRatio,
    uint256 assetAmount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    TestFuzzSwapAssetVars memory vars;

    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 27));
    buyFeeBps = bound(buyFeeBps, 0, 5000 - 1);
    sellFeeBps = bound(sellFeeBps, 0, 5000 - 1);
    priceRatio = bound(priceRatio, 0.01e18, 100e18);
    assetAmount = bound(assetAmount, 1, type(uint64).max - 1);

    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);
    vm.prank(FAUCET);
    newToken.mint(ALICE, assetAmount);

    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      priceRatio,
      address(newToken),
      underlyingDecimals // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, uint128(assetAmount), address(GHO_RESERVE));
    GHO_RESERVE.setEntityLimit(address(gsm), type(uint256).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      gsm.updateFeeStrategy(address(newFeeStrategy));
    }

    vm.startPrank(ALICE);
    newToken.approve(address(gsm), type(uint256).max);

    uint256 userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 userAssetBefore = newToken.balanceOf(ALICE);

    // Calculate GHO amount to purchase with given asset amount, bail if 0
    (, vars.estGhoAmount1, vars.estGrossAmount1, vars.estFeeAmount1) = gsm.getGhoAmountForSellAsset(
      assetAmount
    );
    vm.assume(vars.estGhoAmount1 > 0);
    deal(address(GHO_TOKEN), address(GHO_RESERVE), type(uint256).max);

    (vars.exactAssetAmount, vars.exactGhoAmount) = gsm.sellAsset(assetAmount, ALICE);

    // Calculate asset amount needed for the amount of GHO required to buy
    (vars.estAssetAmount2, , vars.estGrossAmount2, vars.estFeeAmount2) = gsm
      .getAssetAmountForSellAsset(vars.exactGhoAmount);

    assertEq(
      userAssetBefore - newToken.balanceOf(ALICE),
      vars.exactAssetAmount,
      'real assets sold are not equal to the exact amount'
    );
    assertTrue(
      userAssetBefore - newToken.balanceOf(ALICE) <= assetAmount,
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
      userAssetBefore - newToken.balanceOf(ALICE),
      vars.estAssetAmount2,
      'real assets sold does not match estimated value'
    );

    // 1 wei precision error
    assertApproxEqAbs(
      vars.estGrossAmount1,
      vars.estGrossAmount2,
      1,
      'estimated gross amounts do not match'
    );
    assertApproxEqAbs(vars.estFeeAmount1, vars.estFeeAmount2, 1, 'estimated fees do not match');

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
    uint256 priceRatio,
    uint256 assetAmount,
    uint256 buyFeeBps,
    uint256 sellFeeBps
  ) public {
    TestFuzzSwapAssetVars memory vars;

    underlyingDecimals = uint8(bound(underlyingDecimals, 5, 27));
    buyFeeBps = bound(buyFeeBps, 0, 5000 - 1);
    sellFeeBps = bound(sellFeeBps, 0, 5000 - 1);
    priceRatio = bound(priceRatio, 0.01e18, 100e18);
    assetAmount = bound(assetAmount, 1, type(uint64).max - 1);

    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', underlyingDecimals, FAUCET);

    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      priceRatio,
      address(newToken),
      underlyingDecimals // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, type(uint128).max, address(GHO_RESERVE));
    GHO_RESERVE.setEntityLimit(address(gsm), type(uint256).max);

    if (buyFeeBps > 0 || sellFeeBps > 0) {
      FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(buyFeeBps, sellFeeBps);
      gsm.updateFeeStrategy(address(newFeeStrategy));
    }

    // Alice sells some assets to the GSM, so the purchase is doable
    uint256 sellAssetAmount = newPriceStrategy.getGhoPriceInAsset(type(uint128).max, false);
    if (sellAssetAmount > type(uint128).max) {
      sellAssetAmount = type(uint128).max;
    }

    deal(address(GHO_TOKEN), address(GHO_RESERVE), type(uint256).max);

    vm.prank(FAUCET);
    newToken.mint(ALICE, sellAssetAmount);

    vm.startPrank(ALICE);
    newToken.approve(address(gsm), type(uint256).max);
    gsm.sellAsset(sellAssetAmount, ALICE);
    vm.stopPrank();

    // rough estimation of GHO funds needed for buyAsset
    (, uint256 estGhoBought, , ) = gsm.getGhoAmountForBuyAsset(assetAmount);
    ghoFaucet(ALICE, estGhoBought * 20);

    deal(address(GHO_TOKEN), address(GHO_RESERVE), estGhoBought);

    // Buy
    vm.startPrank(ALICE);
    uint256 userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 userAssetBefore = newToken.balanceOf(ALICE);

    // Calculate GHO amount to sell with given asset amount
    (, vars.estGhoAmount1, vars.estGrossAmount1, vars.estFeeAmount1) = gsm.getGhoAmountForBuyAsset(
      assetAmount
    );

    userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    userAssetBefore = newToken.balanceOf(ALICE);

    GHO_TOKEN.approve(address(gsm), type(uint256).max);
    (vars.exactAssetAmount, vars.exactGhoAmount) = gsm.buyAsset(assetAmount, ALICE);

    // Calculate asset amount can be bought for the amount of GHO available
    (vars.estAssetAmount2, vars.estGhoAmount2, vars.estGrossAmount2, vars.estFeeAmount2) = gsm
      .getAssetAmountForBuyAsset(vars.exactGhoAmount);

    assertEq(
      newToken.balanceOf(ALICE) - userAssetBefore,
      vars.exactAssetAmount,
      'real assets bought are not equal to the exact amount'
    );
    assertTrue(
      newToken.balanceOf(ALICE) - userAssetBefore >= assetAmount,
      'real assets bought are less than the input'
    );
    assertEq(
      newToken.balanceOf(ALICE) - userAssetBefore,
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

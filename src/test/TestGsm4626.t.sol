// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsm4626 is TestGhoBase {
  using PercentageMath for uint256;
  using PercentageMath for uint128;

  function testConstructor() public {
    Gsm4626 gsm = new Gsm4626(
      address(GHO_TOKEN),
      address(USDC_4626_TOKEN),
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY)
    );
    assertEq(gsm.GHO_TOKEN(), address(GHO_TOKEN), 'Unexpected GHO token address');
    assertEq(
      gsm.UNDERLYING_ASSET(),
      address(USDC_4626_TOKEN),
      'Unexpected underlying asset address'
    );
    assertEq(
      gsm.PRICE_STRATEGY(),
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY),
      'Unexpected price strategy'
    );
  }

  function testRevertConstructorInvalidPriceStrategy() public {
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(1e18, address(GHO_TOKEN), 18);
    vm.expectRevert('INVALID_PRICE_STRATEGY');
    new Gsm4626(address(GHO_TOKEN), address(USDC_4626_TOKEN), address(newPriceStrategy));
  }

  function testRevertConstructorZeroAddressParams() public {
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new Gsm4626(address(0), address(USDC_4626_TOKEN), address(GHO_GSM_4626_FIXED_PRICE_STRATEGY));

    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new Gsm4626(address(GHO_TOKEN), address(0), address(GHO_GSM_4626_FIXED_PRICE_STRATEGY));
  }

  function testInitialize() public {
    Gsm4626 gsm = new Gsm4626(
      address(GHO_TOKEN),
      address(USDC_4626_TOKEN),
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY)
    );
    vm.expectEmit(true, true, true, true);
    emit RoleGranted(DEFAULT_ADMIN_ROLE, address(this), address(this));
    vm.expectEmit(true, true, false, true);
    emit ExposureCapUpdated(0, DEFAULT_GSM_USDC_EXPOSURE);
    gsm.initialize(address(this), TREASURY, DEFAULT_GSM_USDC_EXPOSURE);
  }

  function testRevertInitializeTwice() public {
    Gsm4626 gsm = new Gsm4626(
      address(GHO_TOKEN),
      address(USDC_4626_TOKEN),
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY)
    );
    gsm.initialize(address(this), TREASURY, DEFAULT_GSM_USDC_EXPOSURE);
    vm.expectRevert('Contract instance has already been initialized');
    gsm.initialize(address(this), TREASURY, DEFAULT_GSM_USDC_EXPOSURE);
  }

  function testSellAssetZeroFee() public {
    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit FeeStrategyUpdated(address(GHO_GSM_FIXED_FEE_STRATEGY), address(0));
    GHO_GSM_4626.updateFeeStrategy(address(0));

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);

    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, 0);
    (uint256 assetAmount, uint256 ghoBought) = GHO_GSM_4626.sellAsset(
      DEFAULT_GSM_USDC_AMOUNT,
      ALICE
    );
    vm.stopPrank();

    assertEq(ghoBought, DEFAULT_GSM_GHO_AMOUNT, 'Unexpected GHO amount bought');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount sold');
    assertEq(USDC_4626_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), DEFAULT_GSM_GHO_AMOUNT, 'Unexpected final GHO balance');
  }

  function testSellAsset() public {
    uint256 fee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = DEFAULT_GSM_GHO_AMOUNT - fee;

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    assertEq(
      USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(ALICE)),
      DEFAULT_GSM_USDC_AMOUNT
    );

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, fee);
    (uint256 assetAmount, uint256 ghoBought) = GHO_GSM_4626.sellAsset(
      DEFAULT_GSM_USDC_AMOUNT,
      ALICE
    );
    vm.stopPrank();

    assertEq(ghoBought, DEFAULT_GSM_GHO_AMOUNT - fee, 'Unexpected GHO amount bought');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount sold');
    assertEq(USDC_4626_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoOut, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM_4626)), fee, 'Unexpected GSM GHO balance');
    assertEq(
      GHO_GSM_4626.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected available underlying exposure'
    );
    assertEq(
      GHO_GSM_4626.getAvailableLiquidity(),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected available liquidity'
    );
  }

  function testSellAssetSendToOther() public {
    uint256 fee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = DEFAULT_GSM_GHO_AMOUNT - fee;

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, BOB, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, fee);
    (uint256 assetAmount, uint256 ghoBought) = GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    assertEq(ghoBought, DEFAULT_GSM_GHO_AMOUNT - fee, 'Unexpected GHO amount bought');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount sold');
    assertEq(USDC_4626_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), 0, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(BOB), ghoOut, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM_4626)), fee, 'Unexpected GSM GHO balance');
  }

  function testRevertSellAssetTooMuchUnderlyingExposure() public {
    Gsm4626 gsm = new Gsm4626(
      address(GHO_TOKEN),
      address(USDC_4626_TOKEN),
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY)
    );
    gsm.initialize(address(this), TREASURY, DEFAULT_GSM_USDC_EXPOSURE - 1);
    GHO_TOKEN.addFacilitator(address(gsm), 'GSM Modified Exposure Cap', DEFAULT_CAPACITY);

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_EXPOSURE);

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(gsm), DEFAULT_GSM_USDC_EXPOSURE);
    vm.expectRevert('EXOGENOUS_ASSET_EXPOSURE_TOO_HIGH');
    gsm.sellAsset(DEFAULT_GSM_USDC_EXPOSURE, ALICE);
    vm.stopPrank();
  }

  function testGetGhoAmountForSellAsset() public {
    (uint256 exactAssetAmount, uint256 ghoBought, uint256 grossAmount, uint256 fee) = GHO_GSM_4626
      .getGhoAmountForSellAsset(DEFAULT_GSM_USDC_AMOUNT);

    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    assertEq(
      DEFAULT_GSM_USDC_AMOUNT - USDC_4626_TOKEN.balanceOf(ALICE),
      exactAssetAmount,
      'Unexpected asset amount sold'
    );

    assertEq(ghoBought + fee, grossAmount, 'Unexpected GHO gross amount');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoBought, 'Unexpected GHO bought amount');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM_4626)), fee, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 exactGhoBought, uint256 grossAmount2, uint256 fee2) = GHO_GSM_4626
      .getAssetAmountForSellAsset(ghoBought);
    assertEq(GHO_TOKEN.balanceOf(ALICE), exactGhoBought, 'Unexpected GHO bought amount');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected estimation of sold assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testGetGhoAmountForSellAssetWithZeroFee() public {
    GHO_GSM_4626.updateFeeStrategy(address(0));

    (uint256 exactAssetAmount, uint256 ghoBought, uint256 grossAmount, uint256 fee) = GHO_GSM_4626
      .getGhoAmountForSellAsset(DEFAULT_GSM_USDC_AMOUNT);
    assertEq(fee, 0, 'Unexpected GHO fee amount');

    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    assertEq(
      DEFAULT_GSM_USDC_AMOUNT - USDC_4626_TOKEN.balanceOf(ALICE),
      exactAssetAmount,
      'Unexpected asset amount sold'
    );
    assertEq(ghoBought, grossAmount, 'Unexpected GHO gross amount');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoBought, 'Unexpected GHO bought amount');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM_4626)), 0, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 exactGhoBought, uint256 grossAmount2, uint256 fee2) = GHO_GSM_4626
      .getAssetAmountForSellAsset(ghoBought);
    assertEq(GHO_TOKEN.balanceOf(ALICE), exactGhoBought, 'Unexpected GHO bought amount');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected estimation of sold assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testGetGhoAmountForSellAssetWithZeroAmount() public {
    (uint256 exactAssetAmount, uint256 ghoBought, uint256 grossAmount, uint256 fee) = GHO_GSM_4626
      .getGhoAmountForSellAsset(0);
    assertEq(exactAssetAmount, 0, 'Unexpected exact asset amount');
    assertEq(ghoBought, 0, 'Unexpected GHO bought amount');
    assertEq(grossAmount, 0, 'Unexpected GHO gross amount');
    assertEq(fee, 0, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 exactGhoBought, uint256 grossAmount2, uint256 fee2) = GHO_GSM_4626
      .getAssetAmountForSellAsset(ghoBought);
    assertEq(exactGhoBought, 0, 'Unexpected exact gho bought');
    assertEq(assetAmount, 0, 'Unexpected estimation of sold assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testBuyAssetZeroFee() public {
    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit FeeStrategyUpdated(address(GHO_GSM_FIXED_FEE_STRATEGY), address(0));
    GHO_GSM_4626.updateFeeStrategy(address(0));

    // Supply assets to the GSM first
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, 0);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    // Buy assets as another user
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_GHO_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit BuyAsset(BOB, BOB, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, 0);
    (uint256 assetAmount, uint256 ghoSold) = GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    assertEq(ghoSold, DEFAULT_GSM_GHO_AMOUNT, 'Unexpected GHO amount sold');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount bought');
    assertEq(
      USDC_4626_TOKEN.balanceOf(BOB),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected final USDC balance'
    );
    assertEq(GHO_TOKEN.balanceOf(ALICE), DEFAULT_GSM_GHO_AMOUNT, 'Unexpected final GHO balance');
  }

  function testBuyAsset() public {
    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);
    uint256 ghoOut = DEFAULT_GSM_GHO_AMOUNT - sellFee;

    // Supply assets to the GSM first
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, sellFee);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    // Buy assets as another user
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit BuyAsset(BOB, BOB, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT + buyFee, buyFee);
    (uint256 assetAmount, uint256 ghoSold) = GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    assertEq(ghoSold, DEFAULT_GSM_GHO_AMOUNT + buyFee, 'Unexpected GHO amount sold');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount bought');
    assertEq(
      USDC_4626_TOKEN.balanceOf(BOB),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected final USDC balance'
    );
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoOut, 'Unexpected final GHO balance');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      sellFee + buyFee,
      'Unexpected GSM GHO balance'
    );
    assertEq(
      GHO_GSM_4626.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE,
      'Unexpected available underlying exposure'
    );
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), 0, 'Unexpected available liquidity');
  }

  function testBuyAssetSendToOther() public {
    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);
    uint256 ghoOut = DEFAULT_GSM_GHO_AMOUNT - sellFee;

    // Supply assets to the GSM first
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, sellFee);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    // Buy assets as another user
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit BuyAsset(BOB, CHARLES, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT + buyFee, buyFee);
    (uint256 assetAmount, uint256 ghoSold) = GHO_GSM_4626.buyAsset(
      DEFAULT_GSM_USDC_AMOUNT,
      CHARLES
    );
    vm.stopPrank();

    assertEq(ghoSold, DEFAULT_GSM_GHO_AMOUNT + buyFee, 'Unexpected GHO amount sold');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount bought');
    assertEq(USDC_4626_TOKEN.balanceOf(BOB), 0, 'Unexpected final USDC balance');
    assertEq(
      USDC_4626_TOKEN.balanceOf(CHARLES),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected final USDC balance'
    );
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoOut, 'Unexpected final GHO balance');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      sellFee + buyFee,
      'Unexpected GSM GHO balance'
    );
  }

  function testBuyThenSellAtMaximumBucketCapacity() public {
    // Use zero fees to simplify amount calculations
    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit FeeStrategyUpdated(address(GHO_GSM_FIXED_FEE_STRATEGY), address(0));
    GHO_GSM_4626.updateFeeStrategy(address(0));

    // Supply assets to the GSM first
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_EXPOSURE);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_EXPOSURE);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_EXPOSURE, DEFAULT_CAPACITY, 0);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_EXPOSURE, ALICE);

    (uint256 ghoCapacity, uint256 ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, ghoCapacity, 'Unexpected GHO bucket level after initial sell');
    assertEq(
      GHO_TOKEN.balanceOf(ALICE),
      DEFAULT_CAPACITY,
      'Unexpected Alice GHO balance after sell'
    );

    // Buy 1 of the underlying
    GHO_TOKEN.approve(address(GHO_GSM_4626), 1e18);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit BuyAsset(ALICE, ALICE, 1e6, 1e18, 0);
    GHO_GSM_4626.buyAsset(1e6, ALICE);

    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, DEFAULT_CAPACITY - 1e18, 'Unexpected GHO bucket level after buy');
    assertEq(
      GHO_TOKEN.balanceOf(ALICE),
      DEFAULT_CAPACITY - 1e18,
      'Unexpected Alice GHO balance after buy'
    );
    assertEq(USDC_4626_TOKEN.balanceOf(ALICE), 1e6, 'Unexpected Alice USDC balance after buy');

    // Sell 1 of the underlying
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), 1e6);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, 1e6, 1e18, 0);
    GHO_GSM_4626.sellAsset(1e6, ALICE);
    vm.stopPrank();

    (ghoCapacity, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, ghoCapacity, 'Unexpected GHO bucket level after second sell');
    assertEq(
      GHO_TOKEN.balanceOf(ALICE),
      DEFAULT_CAPACITY,
      'Unexpected Alice GHO balance after second sell'
    );
    assertEq(
      USDC_4626_TOKEN.balanceOf(ALICE),
      0,
      'Unexpected Alice USDC balance after second sell'
    );
  }

  function testRevertBuyAssetZeroAmount() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_AMOUNT');
    GHO_GSM_4626.buyAsset(0, ALICE);
  }

  function testRevertBuyAssetNoGHO() public {
    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);

    // Supply assets to the GSM first
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, sellFee);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.expectRevert(stdError.arithmeticError);
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();
  }

  function testRevertBuyAssetNoAllowance() public {
    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);

    // Supply assets to the GSM first
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, sellFee);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    vm.expectRevert(stdError.arithmeticError);
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();
  }

  function testGetGhoAmountForBuyAsset() public {
    (uint256 exactAssetAmount, uint256 ghoSold, uint256 grossAmount, uint256 fee) = GHO_GSM_4626
      .getGhoAmountForBuyAsset(DEFAULT_GSM_USDC_AMOUNT);

    uint256 topUpAmount = 1_000_000e18;
    ghoFaucet(ALICE, topUpAmount);

    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    uint256 ghoBalanceBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 ghoFeesBefore = GHO_TOKEN.balanceOf(address(GHO_GSM_4626));

    vm.startPrank(ALICE);
    GHO_TOKEN.approve(address(GHO_GSM_4626), type(uint256).max);
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(DEFAULT_GSM_USDC_AMOUNT, exactAssetAmount, 'Unexpected asset amount bought');
    assertEq(ghoSold - fee, grossAmount, 'Unexpected GHO gross sold amount');
    assertEq(ghoBalanceBefore - GHO_TOKEN.balanceOf(ALICE), ghoSold, 'Unexpected GHO sold amount');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)) - ghoFeesBefore,
      fee,
      'Unexpected GHO fee amount'
    );

    (uint256 assetAmount, uint256 exactGhoSold, uint256 grossAmount2, uint256 fee2) = GHO_GSM_4626
      .getAssetAmountForBuyAsset(ghoSold);
    assertEq(
      ghoBalanceBefore - GHO_TOKEN.balanceOf(ALICE),
      exactGhoSold,
      'Unexpected GHO sold exact amount'
    );
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected estimation of bought assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testGetGhoAmountForBuyAssetWithZeroFee() public {
    GHO_GSM_4626.updateFeeStrategy(address(0));

    (uint256 exactAssetAmount, uint256 ghoSold, uint256 grossAmount, uint256 fee) = GHO_GSM_4626
      .getGhoAmountForBuyAsset(DEFAULT_GSM_USDC_AMOUNT);
    assertEq(fee, 0, 'Unexpected GHO fee amount');

    uint256 topUpAmount = 1_000_000e18;
    ghoFaucet(ALICE, topUpAmount);

    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    uint256 ghoBalanceBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 ghoFeesBefore = GHO_TOKEN.balanceOf(address(GHO_GSM_4626));

    vm.startPrank(ALICE);
    GHO_TOKEN.approve(address(GHO_GSM_4626), type(uint256).max);
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(DEFAULT_GSM_USDC_AMOUNT, exactAssetAmount, 'Unexpected asset amount bought');
    assertEq(ghoSold, grossAmount, 'Unexpected GHO gross sold amount');
    assertEq(ghoBalanceBefore - GHO_TOKEN.balanceOf(ALICE), ghoSold, 'Unexpected GHO sold amount');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      ghoFeesBefore,
      'Unexpected GHO fee amount'
    );

    (uint256 assetAmount, uint256 exactGhoSold, uint256 grossAmount2, uint256 fee2) = GHO_GSM_4626
      .getAssetAmountForBuyAsset(ghoSold);
    assertEq(
      ghoBalanceBefore - GHO_TOKEN.balanceOf(ALICE),
      exactGhoSold,
      'Unexpected GHO sold exact amount'
    );
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected estimation of bought assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testGetGhoAmountForBuyAssetWithZeroAmount() public {
    (uint256 exactAssetAmount, uint256 ghoSold, uint256 grossAmount, uint256 fee) = GHO_GSM_4626
      .getGhoAmountForBuyAsset(0);
    assertEq(exactAssetAmount, 0, 'Unexpected exact asset amount');
    assertEq(ghoSold, 0, 'Unexpected GHO sold amount');
    assertEq(grossAmount, 0, 'Unexpected GHO gross amount');
    assertEq(fee, 0, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 exactGhoSold, uint256 grossAmount2, uint256 fee2) = GHO_GSM_4626
      .getAssetAmountForBuyAsset(ghoSold);
    assertEq(exactGhoSold, 0, 'Unexpected exact gho bought');
    assertEq(assetAmount, 0, 'Unexpected estimation of bought assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testSwapFreeze() public {
    assertEq(GHO_GSM_4626.getIsFrozen(), false, 'Unexpected freeze status before');
    vm.prank(address(GHO_GSM_SWAP_FREEZER));
    vm.expectEmit(true, false, false, true, address(GHO_GSM_4626));
    emit SwapFreeze(address(GHO_GSM_SWAP_FREEZER), true);
    GHO_GSM_4626.setSwapFreeze(true);
    assertEq(GHO_GSM_4626.getIsFrozen(), true, 'Unexpected freeze status after');
  }

  function testRevertFreezeNotAuthorized() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_SWAP_FREEZER_ROLE, ALICE));
    vm.prank(ALICE);
    GHO_GSM_4626.setSwapFreeze(true);
  }

  function testRevertSwapFreezeAlreadyFrozen() public {
    vm.startPrank(address(GHO_GSM_SWAP_FREEZER));
    GHO_GSM_4626.setSwapFreeze(true);
    vm.expectRevert('GSM_ALREADY_FROZEN');
    GHO_GSM_4626.setSwapFreeze(true);
    vm.stopPrank();
  }

  function testSwapUnfreeze() public {
    vm.startPrank(address(GHO_GSM_SWAP_FREEZER));
    GHO_GSM_4626.setSwapFreeze(true);
    vm.expectEmit(true, false, false, true, address(GHO_GSM_4626));
    emit SwapFreeze(address(GHO_GSM_SWAP_FREEZER), false);
    GHO_GSM_4626.setSwapFreeze(false);
    vm.stopPrank();
  }

  function testRevertUnfreezeNotAuthorized() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_SWAP_FREEZER_ROLE, ALICE));
    vm.prank(ALICE);
    GHO_GSM_4626.setSwapFreeze(false);
  }

  function testRevertUnfreezeNotFrozen() public {
    vm.prank(address(GHO_GSM_SWAP_FREEZER));
    vm.expectRevert('GSM_ALREADY_UNFROZEN');
    GHO_GSM_4626.setSwapFreeze(false);
  }

  function testRevertBuyAndSellWhenSwapFrozen() public {
    vm.prank(address(GHO_GSM_SWAP_FREEZER));
    GHO_GSM_4626.setSwapFreeze(true);
    vm.expectRevert('GSM_FROZEN');
    GHO_GSM_4626.buyAsset(0, ALICE);
    vm.expectRevert('GSM_FROZEN');
    GHO_GSM_4626.sellAsset(0, ALICE);
  }

  function testUpdateConfigurator() public {
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit RoleGranted(GSM_CONFIGURATOR_ROLE, ALICE, address(this));
    GHO_GSM_4626.grantRole(GSM_CONFIGURATOR_ROLE, ALICE);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit RoleRevoked(GSM_CONFIGURATOR_ROLE, address(this), address(this));
    GHO_GSM_4626.revokeRole(GSM_CONFIGURATOR_ROLE, address(this));
  }

  function testRevertUpdateConfiguratorNotAuthorized() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(DEFAULT_ADMIN_ROLE, ALICE));
    vm.prank(ALICE);
    GHO_GSM_4626.grantRole(GSM_CONFIGURATOR_ROLE, ALICE);
  }

  function testConfiguratorUpdateMethods() public {
    // Alice as configurator
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit RoleGranted(GSM_CONFIGURATOR_ROLE, ALICE, address(this));
    GHO_GSM_4626.grantRole(GSM_CONFIGURATOR_ROLE, ALICE);

    vm.startPrank(address(ALICE));

    assertEq(
      GHO_GSM_4626.getFeeStrategy(),
      address(GHO_GSM_FIXED_FEE_STRATEGY),
      'Unexpected fee strategy'
    );
    FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(
      DEFAULT_GSM_BUY_FEE,
      DEFAULT_GSM_SELL_FEE
    );
    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit FeeStrategyUpdated(address(GHO_GSM_FIXED_FEE_STRATEGY), address(newFeeStrategy));
    GHO_GSM_4626.updateFeeStrategy(address(newFeeStrategy));
    assertEq(GHO_GSM_4626.getFeeStrategy(), address(newFeeStrategy), 'Unexpected fee strategy');

    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit ExposureCapUpdated(DEFAULT_GSM_USDC_EXPOSURE, 0);
    GHO_GSM_4626.updateExposureCap(0);

    vm.stopPrank();
  }

  function testRevertConfiguratorUpdateMethodsNotAuthorized() public {
    vm.startPrank(ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(DEFAULT_ADMIN_ROLE, ALICE));
    GHO_GSM_4626.grantRole(GSM_LIQUIDATOR_ROLE, ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(DEFAULT_ADMIN_ROLE, ALICE));
    GHO_GSM_4626.grantRole(GSM_SWAP_FREEZER_ROLE, ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    GHO_GSM_4626.updateExposureCap(0);
    vm.stopPrank();
  }

  function testUpdateGhoTreasuryRevertIfZero() public {
    vm.expectRevert(bytes('ZERO_ADDRESS_NOT_VALID'));
    GHO_GSM_4626.updateGhoTreasury(address(0));
  }

  function testUpdateGhoTreasury() public {
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit GhoTreasuryUpdated(TREASURY, ALICE);
    GHO_GSM_4626.updateGhoTreasury(ALICE);

    assertEq(GHO_GSM_4626.getGhoTreasury(), ALICE);
  }

  function testUnauthorizedUpdateGhoTreasuryRevert() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    vm.prank(ALICE);
    GHO_GSM_4626.updateGhoTreasury(ALICE);
  }

  function testRescueTokens() public {
    GHO_GSM_4626.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    vm.prank(FAUCET);
    WETH.mint(address(GHO_GSM_4626), 100e18);
    assertEq(WETH.balanceOf(address(GHO_GSM_4626)), 100e18, 'Unexpected GSM WETH before balance');
    assertEq(WETH.balanceOf(ALICE), 0, 'Unexpected target WETH before balance');
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit TokensRescued(address(WETH), ALICE, 100e18);
    GHO_GSM_4626.rescueTokens(address(WETH), ALICE, 100e18);
    assertEq(WETH.balanceOf(address(GHO_GSM_4626)), 0, 'Unexpected GSM WETH after balance');
    assertEq(WETH.balanceOf(ALICE), 100e18, 'Unexpected target WETH after balance');
  }

  function testRescueGhoTokens() public {
    GHO_GSM_4626.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    ghoFaucet(address(GHO_GSM_4626), 100e18);
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      100e18,
      'Unexpected GSM GHO before balance'
    );
    assertEq(GHO_TOKEN.balanceOf(ALICE), 0, 'Unexpected target GHO before balance');
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit TokensRescued(address(GHO_TOKEN), ALICE, 100e18);
    GHO_GSM_4626.rescueTokens(address(GHO_TOKEN), ALICE, 100e18);
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM_4626)), 0, 'Unexpected GSM GHO after balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), 100e18, 'Unexpected target GHO after balance');
  }

  function testRescueGhoTokensWithAccruedFees() public {
    GHO_GSM_4626.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    uint256 fee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    assertGt(fee, 0, 'Fee not greater than zero');

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);

    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, fee);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM_4626)), fee, 'Unexpected GSM GHO balance');

    ghoFaucet(address(GHO_GSM_4626), 1);
    assertEq(GHO_TOKEN.balanceOf(BOB), 0, 'Unexpected target GHO balance before');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      fee + 1,
      'Unexpected GSM GHO balance before'
    );

    vm.expectRevert('INSUFFICIENT_GHO_TO_RESCUE');
    GHO_GSM_4626.rescueTokens(address(GHO_TOKEN), BOB, fee);

    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit TokensRescued(address(GHO_TOKEN), BOB, 1);
    GHO_GSM_4626.rescueTokens(address(GHO_TOKEN), BOB, 1);

    assertEq(GHO_TOKEN.balanceOf(BOB), 1, 'Unexpected target GHO balance after');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM_4626)), fee, 'Unexpected GSM GHO balance after');
  }

  function testRevertRescueGhoTokens() public {
    GHO_GSM_4626.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    vm.expectRevert('INSUFFICIENT_GHO_TO_RESCUE');
    GHO_GSM_4626.rescueTokens(address(GHO_TOKEN), ALICE, 1);
  }

  function testRescueUnderlyingTokens() public {
    GHO_GSM_4626.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);

    assertEq(USDC_4626_TOKEN.balanceOf(ALICE), 0, 'Unexpected USDC balance before');
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit TokensRescued(address(USDC_4626_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.rescueTokens(address(USDC_4626_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    assertEq(
      USDC_4626_TOKEN.balanceOf(ALICE),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected USDC balance after'
    );
  }

  function testRescueUnderlyingTokensWithAccruedFees() public {
    GHO_GSM_4626.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    uint256 currentGSMBalance = DEFAULT_GSM_USDC_AMOUNT;
    assertEq(
      USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)),
      currentGSMBalance,
      'Unexpected GSM USDC balance before'
    );

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);

    assertEq(
      USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)),
      currentGSMBalance + DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected GSM USDC balance before, post-mint'
    );
    assertEq(USDC_4626_TOKEN.balanceOf(ALICE), 0, 'Unexpected target USDC balance before');

    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit TokensRescued(address(USDC_4626_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.rescueTokens(address(USDC_4626_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    assertEq(
      USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)),
      currentGSMBalance,
      'Unexpected GSM USDC balance after'
    );
    assertEq(
      USDC_4626_TOKEN.balanceOf(ALICE),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected target USDC balance after'
    );
  }

  function testRevertRescueUnderlyingTokens() public {
    GHO_GSM_4626.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    vm.expectRevert('INSUFFICIENT_EXOGENOUS_ASSET_TO_RESCUE');
    GHO_GSM_4626.rescueTokens(address(USDC_4626_TOKEN), ALICE, 1);
  }

  function testSeize() public {
    assertEq(GHO_GSM_4626.getIsSeized(), false, 'Unexpected seize status before');

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(USDC_4626_TOKEN.balanceOf(TREASURY), 0, 'Unexpected USDC before token balance');
    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    vm.expectEmit(true, false, false, true, address(GHO_GSM_4626));
    emit Seized(
      address(GHO_GSM_LAST_RESORT_LIQUIDATOR),
      BOB,
      DEFAULT_GSM_USDC_AMOUNT,
      DEFAULT_GSM_GHO_AMOUNT
    );
    uint256 seizedAmount = GHO_GSM_4626.seize();
    assertEq(seizedAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected seized amount');

    assertEq(GHO_GSM_4626.getIsSeized(), true, 'Unexpected seize status after');
    assertEq(
      USDC_4626_TOKEN.balanceOf(TREASURY),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected USDC after token balance'
    );
  }

  function testRevertSeizeWithoutAuthorization() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_LIQUIDATOR_ROLE, address(this)));
    GHO_GSM_4626.seize();
  }

  function testRevertMethodsAfterSeizure() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    uint256 seizedAmount = GHO_GSM_4626.seize();
    assertEq(seizedAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected seized amount');

    vm.expectRevert('GSM_SEIZED');
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.expectRevert('GSM_SEIZED');
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.expectRevert('GSM_SEIZED');
    GHO_GSM_4626.seize();

    GHO_GSM_4626.grantRole(GSM_CONFIGURATOR_ROLE, BOB);
    vm.startPrank(BOB);
    vm.expectRevert('GSM_SEIZED');
    GHO_GSM_4626.backWithGho(1);
    vm.expectRevert('GSM_SEIZED');
    GHO_GSM_4626.backWithUnderlying(1);
    vm.stopPrank();
  }

  function testBurnAfterSeize() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    uint256 seizedAmount = GHO_GSM_4626.seize();
    assertEq(seizedAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected seized amount');

    vm.expectRevert('FACILITATOR_BUCKET_LEVEL_NOT_ZERO');
    GHO_TOKEN.removeFacilitator(address(GHO_GSM_4626));

    ghoFaucet(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT);
    vm.startPrank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_GHO_AMOUNT);
    vm.expectEmit(true, false, false, true, address(GHO_GSM_4626));
    emit BurnAfterSeize(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT, 0);
    uint256 burnedAmount = GHO_GSM_4626.burnAfterSeize(DEFAULT_GSM_GHO_AMOUNT);
    vm.stopPrank();
    assertEq(burnedAmount, DEFAULT_GSM_GHO_AMOUNT, 'Unexpected burned amount of GHO');

    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorRemoved(address(GHO_GSM_4626));
    GHO_TOKEN.removeFacilitator(address(GHO_GSM_4626));
  }

  function testBurnAfterSeizeGreaterAmount() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    uint256 seizedAmount = GHO_GSM_4626.seize();
    assertEq(seizedAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected seized amount');

    ghoFaucet(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT + 1);
    vm.startPrank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_GHO_AMOUNT + 1);
    vm.expectEmit(true, false, false, true, address(GHO_GSM_4626));
    emit BurnAfterSeize(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT, 0);
    uint256 burnedAmount = GHO_GSM_4626.burnAfterSeize(DEFAULT_GSM_GHO_AMOUNT + 1);
    vm.stopPrank();
    assertEq(burnedAmount, DEFAULT_GSM_GHO_AMOUNT, 'Unexpected burned amount of GHO');
  }

  function testRevertBurnAfterInvalidAmount() public {
    vm.startPrank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM_4626.seize();
    vm.expectRevert('INVALID_AMOUNT');
    GHO_GSM_4626.burnAfterSeize(0);
    vm.stopPrank();
  }

  function testRevertBurnAfterSeizeNotSeized() public {
    vm.expectRevert('GSM_NOT_SEIZED');
    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM_4626.burnAfterSeize(1);
  }

  function testRevertBurnAfterSeizeUnauthorized() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_LIQUIDATOR_ROLE, address(this)));
    GHO_GSM_4626.burnAfterSeize(1);
  }

  function testInjectGho() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    (uint256 excess, uint256 deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');

    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_AMOUNT / 2, false);

    GHO_GSM_4626.grantRole(GSM_CONFIGURATOR_ROLE, BOB);

    (excess, deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, DEFAULT_GSM_GHO_AMOUNT / 2, 'Unexpected deficit of GHO');

    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT / 2);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_GHO_AMOUNT / 2);
    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit BackingProvided(
      BOB,
      address(GHO_TOKEN),
      DEFAULT_GSM_GHO_AMOUNT / 2,
      DEFAULT_GSM_GHO_AMOUNT / 2,
      0
    );
    uint256 ghoUsedForBacking = GHO_GSM_4626.backWithGho(DEFAULT_GSM_GHO_AMOUNT / 2);
    assertEq(DEFAULT_GSM_GHO_AMOUNT / 2, ghoUsedForBacking);
    vm.stopPrank();

    (excess, deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');
  }

  function testInjectGhoMoreThanNeeded() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    (uint256 excess, uint256 deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');

    GHO_GSM_4626.grantRole(GSM_CONFIGURATOR_ROLE, ALICE);

    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_AMOUNT / 2, false);

    ghoFaucet(address(this), (DEFAULT_GSM_GHO_AMOUNT / 2) + 1);
    GHO_TOKEN.approve(address(GHO_GSM_4626), type(uint256).max);

    uint256 balanceBefore = GHO_TOKEN.balanceOf(address(this));
    (, uint256 ghoLevelBefore) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(address(GHO_GSM_4626));

    uint256 ghoUsedForBacking = GHO_GSM_4626.backWithGho((DEFAULT_GSM_GHO_AMOUNT / 2) + 1);

    uint256 balanceAfter = GHO_TOKEN.balanceOf(address(this));
    (, uint256 ghoLevelAfter) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(address(GHO_GSM_4626));

    assertEq(DEFAULT_GSM_GHO_AMOUNT / 2, ghoUsedForBacking);
    assertEq(balanceBefore - balanceAfter, ghoUsedForBacking);
    assertEq(ghoLevelBefore - ghoLevelAfter, ghoUsedForBacking);

    (excess, deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');
  }

  function testInjectUnderlying() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    (uint256 excess, uint256 deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');

    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_AMOUNT / 2, false);

    (excess, deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, DEFAULT_GSM_GHO_AMOUNT / 2, 'Unexpected deficit of GHO');

    GHO_GSM_4626.grantRole(GSM_CONFIGURATOR_ROLE, BOB);

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, BOB, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(BOB);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit BackingProvided(
      BOB,
      address(USDC_4626_TOKEN),
      DEFAULT_GSM_USDC_AMOUNT,
      DEFAULT_GSM_GHO_AMOUNT / 2,
      0
    );
    uint256 usdcUsedForBacking = GHO_GSM_4626.backWithUnderlying(DEFAULT_GSM_USDC_AMOUNT);
    assertEq(DEFAULT_GSM_USDC_AMOUNT, usdcUsedForBacking);
    vm.stopPrank();

    (excess, deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');
  }

  function testInjectUnderlyingMoreThanNeeded() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    (uint256 excess, uint256 deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');

    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_AMOUNT / 2, false);

    (excess, deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, DEFAULT_GSM_GHO_AMOUNT / 2, 'Unexpected deficit of GHO');

    GHO_GSM_4626.grantRole(GSM_CONFIGURATOR_ROLE, BOB);

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, BOB, DEFAULT_GSM_USDC_AMOUNT + 1);

    vm.startPrank(BOB);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT + 1);
    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit BackingProvided(
      BOB,
      address(USDC_4626_TOKEN),
      DEFAULT_GSM_USDC_AMOUNT,
      DEFAULT_GSM_GHO_AMOUNT / 2,
      0
    );
    uint256 usdcUsedForBacking = GHO_GSM_4626.backWithUnderlying(DEFAULT_GSM_USDC_AMOUNT + 1);
    assertEq(DEFAULT_GSM_USDC_AMOUNT, usdcUsedForBacking);
    vm.stopPrank();

    (excess, deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');
  }

  function testRevertBackWithNotAuthorized() public {
    vm.startPrank(ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    GHO_GSM_4626.backWithGho(0);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    GHO_GSM_4626.backWithUnderlying(0);
    vm.stopPrank();
  }

  function testRevertBackWithZeroAmount() public {
    vm.expectRevert('INVALID_AMOUNT');
    GHO_GSM_4626.backWithGho(0);
    vm.expectRevert('INVALID_AMOUNT');
    GHO_GSM_4626.backWithUnderlying(0);
  }

  function testRevertBackWithNoDeficit() public {
    (uint256 excess, uint256 deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');
    vm.expectRevert('NO_CURRENT_DEFICIT_BACKING');
    GHO_GSM_4626.backWithGho(1);
    vm.expectRevert('NO_CURRENT_DEFICIT_BACKING');
    GHO_GSM_4626.backWithUnderlying(1);
  }

  function testDistributeFeesToTreasury() public {
    uint256 fee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, fee);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM_4626)), fee, 'Unexpected GSM GHO balance');
    assertEq(GHO_GSM_4626.getAccruedFees(), fee, 'Unexpected GSM accrued fees');

    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit FeesDistributedToTreasury(
      TREASURY,
      address(GHO_TOKEN),
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626))
    );

    GHO_GSM_4626.distributeFeesToTreasury();

    assertEq(GHO_GSM_4626.getAccruedFees(), 0, 'Unexpected GSM accrued fees');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      0,
      'Unexpected GSM GHO balance post-distribution'
    );
    assertEq(GHO_TOKEN.balanceOf(TREASURY), fee, 'Unexpected GHO balance in treasury');
  }

  function testDistributeYieldToTreasuryDoNothing() public {
    uint256 gsmBalanceBefore = GHO_TOKEN.balanceOf(address(GHO_GSM_4626));
    uint256 treasuryBalanceBefore = GHO_TOKEN.balanceOf(address(TREASURY));
    assertEq(GHO_GSM_4626.getAccruedFees(), 0, 'Unexpected GSM accrued fees');

    vm.record();
    GHO_GSM_4626.distributeFeesToTreasury();
    (, bytes32[] memory writes) = vm.accesses(address(GHO_GSM_4626));
    assertEq(writes.length, 0, 'Unexpected update of accrued fees');

    assertEq(GHO_GSM_4626.getAccruedFees(), 0, 'Unexpected GSM accrued fees');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      gsmBalanceBefore,
      'Unexpected GSM GHO balance post-distribution'
    );
    assertEq(
      GHO_TOKEN.balanceOf(TREASURY),
      treasuryBalanceBefore,
      'Unexpected GHO balance in treasury'
    );
  }

  function testGetAccruedFees() public {
    assertEq(GHO_GSM_4626.getAccruedFees(), 0, 'Unexpected GSM accrued fees');

    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);

    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM_4626)), sellFee, 'Unexpected GSM GHO balance');
    assertEq(GHO_GSM_4626.getAccruedFees(), sellFee, 'Unexpected GSM accrued fees');

    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit BuyAsset(BOB, BOB, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT + buyFee, buyFee);
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      sellFee + buyFee,
      'Unexpected GSM GHO balance'
    );
    assertEq(GHO_GSM_4626.getAccruedFees(), sellFee + buyFee, 'Unexpected GSM accrued fees');
  }

  function testGetAccruedFeesWithZeroFee() public {
    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit FeeStrategyUpdated(address(GHO_GSM_FIXED_FEE_STRATEGY), address(0));
    GHO_GSM_4626.updateFeeStrategy(address(0));

    assertEq(GHO_GSM_4626.getAccruedFees(), 0, 'Unexpected GSM accrued fees');

    for (uint256 i = 0; i < 10; i++) {
      _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
      assertEq(GHO_GSM_4626.getAccruedFees(), 0, 'Unexpected GSM accrued fees');

      ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT);
      vm.startPrank(BOB);
      GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_GHO_AMOUNT);
      GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
      vm.stopPrank();

      assertEq(GHO_GSM_4626.getAccruedFees(), 0, 'Unexpected GSM accrued fees');
    }
  }
}

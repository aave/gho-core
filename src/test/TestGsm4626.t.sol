// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsm4626 is TestGhoBase {
  using PercentageMath for uint256;
  using PercentageMath for uint128;

  function testConstructor() public {
    Gsm4626 gsm = new Gsm4626(address(GHO_TOKEN), address(USDC_TOKEN));
    assertEq(gsm.GHO_TOKEN(), address(GHO_TOKEN), 'Unexpected GHO token address');
    assertEq(gsm.UNDERLYING_ASSET(), address(USDC_TOKEN), 'Unexpected underlying asset address');
  }

  function testInitialize() public {
    Gsm4626 gsm = new Gsm4626(address(GHO_TOKEN), address(USDC_4626_TOKEN));
    vm.expectEmit(true, true, true, true);
    emit RoleGranted(DEFAULT_ADMIN_ROLE, address(this), address(this));
    vm.expectEmit(true, true, false, true);
    emit PriceStrategyUpdated(address(0), address(GHO_GSM_4626_FIXED_PRICE_STRATEGY));
    vm.expectEmit(true, true, false, true);
    emit ExposureCapUpdated(0, DEFAULT_GSM_USDC_EXPOSURE);
    gsm.initialize(
      address(this),
      TREASURY,
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY),
      DEFAULT_GSM_USDC_EXPOSURE
    );
    assertEq(
      gsm.getPriceStrategy(),
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY),
      'Unexpected price strategy'
    );
  }

  function testRevertInitializeTwice() public {
    Gsm4626 gsm = new Gsm4626(address(GHO_TOKEN), address(USDC_4626_TOKEN));
    gsm.initialize(
      address(this),
      TREASURY,
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY),
      DEFAULT_GSM_USDC_EXPOSURE
    );
    vm.expectRevert('Contract instance has already been initialized');
    gsm.initialize(
      address(this),
      TREASURY,
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY),
      DEFAULT_GSM_USDC_EXPOSURE
    );
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
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();
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
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

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

  function testRevertSellAssetTooMuchUnderlyingExposure() public {
    Gsm4626 gsm = new Gsm4626(address(GHO_TOKEN), address(USDC_4626_TOKEN));
    gsm.initialize(
      address(this),
      TREASURY,
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY),
      DEFAULT_GSM_USDC_EXPOSURE - 1
    );
    GHO_TOKEN.addFacilitator(address(gsm), 'GSM Modified Exposure Cap', DEFAULT_CAPACITY);

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_EXPOSURE);

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(gsm), DEFAULT_GSM_USDC_EXPOSURE);
    vm.expectRevert('EXOGENOUS_ASSET_EXPOSURE_TOO_HIGH');
    gsm.sellAsset(DEFAULT_GSM_USDC_EXPOSURE, ALICE);
    vm.stopPrank();
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
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB, false);
    vm.stopPrank();

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
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB, false);
    vm.stopPrank();

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
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, CHARLES, false);
    vm.stopPrank();

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

  function testBuyAssetAtCapacityWithGain() public {
    // Use zero fees for easier calculations
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
    vm.stopPrank();

    (uint256 ghoCapacity, uint256 ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, ghoCapacity, 'Unexpected GHO bucket level after initial sell');

    // Simulate a gain
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_EXPOSURE / 4, true);
    (uint256 excess, uint256 dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, (DEFAULT_GSM_USDC_EXPOSURE / 4) * 1e12, 'Unexpected excess');
    assertEq(dearth, 0, 'Unexpected non-zero dearth');
    uint128 buyAmount = DEFAULT_CAPACITY / (((5 * DEFAULT_GSM_USDC_EXPOSURE) / 4) / 100);

    vm.startPrank(ALICE);
    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_CAPACITY);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit BuyAsset(ALICE, ALICE, buyAmount, DEFAULT_CAPACITY, 0);
    GHO_GSM_4626.buyAsset(buyAmount, ALICE, false);
    vm.stopPrank();

    assertEq(USDC_4626_TOKEN.balanceOf(ALICE), buyAmount, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), 0, 'Unexpected final GHO balance');

    // Ensure GHO level is at 0, but that excess is unchanged
    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, 0, 'Unexpected GHO bucket level after initial sell');
    (excess, dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, (DEFAULT_GSM_USDC_EXPOSURE / 4) * 1e12, 'Unexpected excess');
    assertEq(dearth, 0, 'Unexpected non-zero dearth');

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), 1);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, 1, 1e12, 0);
    GHO_GSM_4626.sellAsset(1, ALICE);
    vm.stopPrank();

    // Ensure GHO level is at 1e12, but that excess is unchanged
    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, 1e12, 'Unexpected GHO bucket level after initial sell');
    (excess, dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, (DEFAULT_GSM_USDC_EXPOSURE / 4) * 1e12, 'Unexpected excess');
    assertEq(dearth, 0, 'Unexpected non-zero dearth');

    vm.startPrank(ALICE);
    GHO_TOKEN.approve(address(GHO_GSM_4626), 1e12);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit BuyAsset(ALICE, ALICE, 1, 1e12, 0);
    GHO_GSM_4626.buyAsset(1, ALICE, false);
    vm.stopPrank();

    // Ensure GHO level is at the previous amount of excess, and excess is now 0
    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(
      ghoLevel,
      (DEFAULT_GSM_USDC_EXPOSURE / 4) * 1e12,
      'Unexpected GHO bucket level after final buy'
    );
    (excess, dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess');
    assertEq(dearth, 0, 'Unexpected non-zero dearth');
  }

  function testRevertBuyAssetZeroAmount() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_AMOUNT');
    GHO_GSM_4626.buyAsset(0, ALICE, false);
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
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB, false);
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
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB, false);
    vm.stopPrank();
  }

  function testBuyTokenizedAsset() public {
    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);
    uint256 ghoOut = DEFAULT_GSM_GHO_AMOUNT - sellFee;

    assertEq(
      GHO_GSM_4626.getGsmToken(),
      address(GHO_GSM_4626_TOKEN),
      'Unexpected GSM token address'
    );

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
    emit BuyTokenizedAsset(
      BOB,
      BOB,
      DEFAULT_GSM_USDC_AMOUNT,
      DEFAULT_GSM_GHO_AMOUNT + buyFee,
      buyFee
    );
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB, true);
    vm.stopPrank();

    assertEq(
      GHO_GSM_4626.getTokenizedAssets(),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected tokenized asset count'
    );
    assertEq(
      GHO_GSM_4626_TOKEN.balanceOf(BOB),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected GSM token amount'
    );
    assertEq(USDC_4626_TOKEN.balanceOf(BOB), 0, 'Unexpected final USDC balance');
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
    assertEq(
      USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected GSM USDC balance'
    );
  }

  function testRevertBuyTokenizedAssetNoGsmToken() public {
    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);

    Gsm4626 gsm = new Gsm4626(address(GHO_TOKEN), address(USDC_4626_TOKEN));
    gsm.initialize(
      address(this),
      TREASURY,
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY),
      DEFAULT_GSM_USDC_EXPOSURE
    );
    gsm.updateFeeStrategy(address(GHO_GSM_FIXED_FEE_STRATEGY));
    GHO_TOKEN.addFacilitator(address(gsm), 'GSM No Token', DEFAULT_CAPACITY);

    vm.startPrank(FAUCET);
    USDC_TOKEN.mint(FAUCET, DEFAULT_GSM_USDC_AMOUNT);
    USDC_TOKEN.approve(address(USDC_4626_TOKEN), DEFAULT_GSM_USDC_AMOUNT);
    USDC_4626_TOKEN.deposit(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(gsm), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(gsm));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, sellFee);
    gsm.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(gsm), DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.expectRevert('NO_GSM_TOKEN');
    gsm.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB, true);
    vm.stopPrank();
  }

  function testRedeemTokenizedAsset() public {
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
    emit BuyTokenizedAsset(
      BOB,
      BOB,
      DEFAULT_GSM_USDC_AMOUNT,
      DEFAULT_GSM_GHO_AMOUNT + buyFee,
      buyFee
    );
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB, true);

    assertEq(
      GHO_GSM_4626_TOKEN.balanceOf(BOB),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected GSM token amount'
    );
    assertEq(USDC_4626_TOKEN.balanceOf(BOB), 0, 'Unexpected USDC balance');
    assertEq(
      USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected GSM USDC balance'
    );

    GHO_GSM_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, false, false, true, address(GHO_GSM_4626));
    emit RedeemTokenizedAsset(BOB, BOB, DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.redeemTokenizedAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);

    assertEq(GHO_GSM_4626_TOKEN.balanceOf(BOB), 0, 'Unexpected GSM token amount');
    assertEq(USDC_4626_TOKEN.balanceOf(BOB), DEFAULT_GSM_USDC_AMOUNT, 'Unexpected USDC balance');
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), 0, 'Unexpected GSM USDC balance');
  }

  function testRevertRedeemTokenizedAssetsInsufficient() public {
    vm.expectRevert('INSUFFICIENT_AVAILABLE_TOKENIZED_ASSETS');
    GHO_GSM_4626.redeemTokenizedAsset(1, BOB);
  }

  function testRevertRedeemZeroTokenizedAssets() public {
    vm.expectRevert('INVALID_AMOUNT');
    GHO_GSM_4626.redeemTokenizedAsset(0, BOB);
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
    vm.expectRevert('GSM_FROZEN_SWAPS_DISABLED');
    GHO_GSM_4626.buyAsset(0, ALICE, false);
    vm.expectRevert('GSM_FROZEN_SWAPS_DISABLED');
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

    GsmToken newGsmToken = new GsmToken(
      address(GHO_GSM_4626),
      'Test',
      'testUSDC',
      6,
      address(USDC_4626_TOKEN)
    );
    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit GsmTokenUpdated(address(GHO_GSM_4626_TOKEN), address(newGsmToken));
    GHO_GSM_4626.updateGsmToken(address(newGsmToken));

    FixedPriceStrategy4626 newPriceStrategy = new FixedPriceStrategy4626(
      DEFAULT_FIXED_PRICE,
      address(USDC_4626_TOKEN),
      6
    );
    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit PriceStrategyUpdated(
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY),
      address(newPriceStrategy)
    );
    GHO_GSM_4626.updatePriceStrategy(address(newPriceStrategy));

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
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    GHO_GSM_4626.updatePriceStrategy(ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(DEFAULT_ADMIN_ROLE, ALICE));
    GHO_GSM_4626.grantRole(GSM_LIQUIDATOR_ROLE, ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(DEFAULT_ADMIN_ROLE, ALICE));
    GHO_GSM_4626.grantRole(GSM_SWAP_FREEZER_ROLE, ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    GHO_GSM_4626.updateExposureCap(0);
    vm.stopPrank();
  }

  function testRevertUpdateGsmTokenInvalidAsset() public {
    GsmToken newGsmToken = new GsmToken(address(GHO_GSM_4626), 'Test', 'test', 6, address(WETH));
    vm.expectRevert('INVALID_GSM_TOKEN_FOR_ASSET');
    GHO_GSM_4626.updateGsmToken(address(newGsmToken));
  }

  function testRevertUpdateGsmTokenHasTokenizedAssets() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);

    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_GHO_AMOUNT);
    GHO_GSM_4626.buyAsset(1, ALICE, true);
    vm.stopPrank();

    vm.expectRevert('GSM_TOKEN_BACKING_GSM_ASSETS');
    GHO_GSM_4626.updateGsmToken(address(GHO_GSM_4626_TOKEN));
  }

  function testUpdatePriceStrategyNoYieldAccrualAtBucketCap() public {
    // Use zero fees for easier calculations
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
    vm.stopPrank();

    (uint256 ghoCapacity, uint256 ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, ghoCapacity, 'Unexpected GHO bucket level after initial sell');

    // Simulate a gain
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_EXPOSURE / 4, true);
    (uint256 excess, uint256 dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, (DEFAULT_GSM_USDC_EXPOSURE / 4) * 1e12, 'Unexpected excess');
    assertEq(dearth, 0, 'Unexpected non-zero dearth');

    // Change the Price Strategy to the same fixed price, to trigger the update and yield accrual
    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit PriceStrategyUpdated(
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY),
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY)
    );
    GHO_GSM_4626.updatePriceStrategy(address(GHO_GSM_4626_FIXED_PRICE_STRATEGY));

    // Ensure excess and dearth are the same
    (excess, dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, (DEFAULT_GSM_USDC_EXPOSURE / 4) * 1e12, 'Unexpected excess');
    assertEq(dearth, 0, 'Unexpected non-zero dearth');
  }

  function testRevertUpdatePriceStrategyZeroAddress() public {
    FixedPriceStrategy wrongPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE,
      address(WETH),
      18
    );
    vm.expectRevert('INVALID_PRICE_STRATEGY_FOR_ASSET');
    GHO_GSM_4626.updatePriceStrategy(address(wrongPriceStrategy));
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

    assertEq(USDC_4626_TOKEN.balanceOf(BOB), 0, 'Unexpected USDC before token balance');
    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    vm.expectEmit(true, false, false, true, address(GHO_GSM_4626));
    emit Seized(
      address(GHO_GSM_LAST_RESORT_LIQUIDATOR),
      BOB,
      DEFAULT_GSM_USDC_AMOUNT,
      DEFAULT_GSM_GHO_AMOUNT
    );
    GHO_GSM_4626.seize(BOB);

    assertEq(GHO_GSM_4626.getIsSeized(), true, 'Unexpected seize status after');
    assertEq(
      USDC_4626_TOKEN.balanceOf(BOB),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected USDC after token balance'
    );
  }

  function testSeizeWithTokenizedAssetsThenRedeem() public {
    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = (DEFAULT_GSM_GHO_AMOUNT / 2).percentMul(DEFAULT_GSM_BUY_FEE);

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);

    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, sellFee);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    GHO_TOKEN.transfer(BOB, (DEFAULT_GSM_GHO_AMOUNT / 2) + buyFee);
    vm.stopPrank();

    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM_4626), (DEFAULT_GSM_GHO_AMOUNT / 2) + buyFee);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit BuyTokenizedAsset(
      BOB,
      BOB,
      DEFAULT_GSM_USDC_AMOUNT / 2,
      (DEFAULT_GSM_GHO_AMOUNT / 2) + buyFee,
      buyFee
    );
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT / 2, BOB, true);
    vm.stopPrank();

    assertEq(USDC_4626_TOKEN.balanceOf(BOB), 0, 'Unexpected USDC token balance');
    assertEq(
      GHO_GSM_4626_TOKEN.balanceOf(BOB),
      DEFAULT_GSM_USDC_AMOUNT / 2,
      'Unexpected GSM Token balance'
    );
    assertEq(
      USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected GSM USDC token balance'
    );

    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    vm.expectEmit(true, false, false, true, address(GHO_GSM_4626));
    emit Seized(
      address(GHO_GSM_LAST_RESORT_LIQUIDATOR),
      ALICE,
      DEFAULT_GSM_USDC_AMOUNT / 2,
      DEFAULT_GSM_GHO_AMOUNT / 2
    );
    GHO_GSM_4626.seize(ALICE);

    assertEq(USDC_4626_TOKEN.balanceOf(BOB), 0, 'Unexpected USDC token balance');
    assertEq(
      GHO_GSM_4626_TOKEN.balanceOf(BOB),
      DEFAULT_GSM_USDC_AMOUNT / 2,
      'Unexpected GSM Token balance'
    );
    assertEq(
      USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)),
      DEFAULT_GSM_USDC_AMOUNT / 2,
      'Unexpected GSM USDC token balance'
    );

    vm.startPrank(BOB);
    GHO_GSM_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT / 2);
    vm.expectEmit(true, false, false, true, address(GHO_GSM_4626));
    emit RedeemTokenizedAsset(BOB, BOB, DEFAULT_GSM_USDC_AMOUNT / 2);
    GHO_GSM_4626.redeemTokenizedAsset(DEFAULT_GSM_USDC_AMOUNT / 2, BOB);
    vm.stopPrank();

    assertEq(
      USDC_4626_TOKEN.balanceOf(BOB),
      DEFAULT_GSM_USDC_AMOUNT / 2,
      'Unexpected USDC token balance'
    );
    assertEq(GHO_GSM_4626_TOKEN.balanceOf(BOB), 0, 'Unexpected GSM Token balance');
    assertEq(
      USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)),
      0,
      'Unexpected GSM USDC token balance'
    );
  }

  function testRevertSeizeWithoutAuthorization() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_LIQUIDATOR_ROLE, address(this)));
    GHO_GSM_4626.seize(BOB);
  }

  function testRevertMethodsAfterSeizure() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM_4626.seize(BOB);

    vm.expectRevert('GSM_SEIZED_SWAPS_DISABLED');
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE, false);
    vm.expectRevert('GSM_SEIZED_SWAPS_DISABLED');
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.expectRevert('GSM_SEIZED_SWAPS_DISABLED');
    GHO_GSM_4626.seize(BOB);
  }

  function testBurnAfterSeize() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM_4626.seize(BOB);

    vm.expectRevert('FACILITATOR_BUCKET_LEVEL_NOT_ZERO');
    GHO_TOKEN.removeFacilitator(address(GHO_GSM_4626));

    ghoFaucet(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT);
    vm.startPrank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_GHO_AMOUNT);
    vm.expectEmit(true, false, false, true, address(GHO_GSM_4626));
    emit BurnAfterSeize(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT, 0);
    GHO_GSM_4626.burnAfterSeize(DEFAULT_GSM_GHO_AMOUNT);
    vm.stopPrank();

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
    GHO_GSM_4626.seize(BOB);

    ghoFaucet(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT + 1);
    vm.startPrank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_GHO_AMOUNT + 1);
    vm.expectEmit(true, false, false, true, address(GHO_GSM_4626));
    emit BurnAfterSeize(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT, 0);
    GHO_GSM_4626.burnAfterSeize(DEFAULT_GSM_GHO_AMOUNT + 1);
    vm.stopPrank();
  }

  function testRevertBurnAfterSeizeNotSeized() public {
    vm.expectRevert('GSM_NOT_SEIZED');
    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM_4626.burnAfterSeize(0);
  }

  function testInjectGho() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    (uint256 excess, uint256 dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(dearth, 0, 'Unexpected dearth of GHO');

    // Cut price of the underlying in half to simulate a loss in underlying value
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE / 2,
      address(USDC_4626_TOKEN),
      6
    );
    GHO_GSM_4626.updatePriceStrategy(address(newPriceStrategy));

    GHO_GSM_4626.grantRole(GSM_CONFIGURATOR_ROLE, BOB);

    (excess, dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(dearth, DEFAULT_GSM_GHO_AMOUNT / 2, 'Unexpected dearth of GHO');

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
    GHO_GSM_4626.backWith(address(GHO_TOKEN), DEFAULT_GSM_GHO_AMOUNT / 2);
    vm.stopPrank();

    (excess, dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(dearth, 0, 'Unexpected dearth of GHO');
  }

  function testInjectUnderlying() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    (uint256 excess, uint256 dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(dearth, 0, 'Unexpected dearth of GHO');

    // Cut price of the underlying in half to simulate a loss in underlying value
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE / 2,
      address(USDC_4626_TOKEN),
      6
    );
    GHO_GSM_4626.updatePriceStrategy(address(newPriceStrategy));

    (excess, dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(dearth, DEFAULT_GSM_GHO_AMOUNT / 2, 'Unexpected dearth of GHO');

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
    GHO_GSM_4626.backWith(address(USDC_4626_TOKEN), DEFAULT_GSM_USDC_AMOUNT);
    vm.stopPrank();

    (excess, dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(dearth, 0, 'Unexpected dearth of GHO');
  }

  function testRevertBackWithInvalidAsset() public {
    vm.expectRevert('INVALID_ASSET');
    GHO_GSM_4626.backWith(address(0), 1);
  }

  function testRevertBackWithNotAuthorized() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    vm.prank(ALICE);
    GHO_GSM_4626.backWith(address(GHO_TOKEN), 0);
  }

  function testRevertBackWithZeroAmount() public {
    vm.expectRevert('INVALID_AMOUNT');
    GHO_GSM_4626.backWith(address(GHO_TOKEN), 0);
  }

  function testRevertBackWithNoDearth() public {
    (uint256 excess, uint256 dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(dearth, 0, 'Unexpected dearth of GHO');
    vm.expectRevert('NO_CURRENT_DEARTH_BACKING');
    GHO_GSM_4626.backWith(address(GHO_TOKEN), 1);
  }

  function testRevertInjectGhoTooMuch() public {
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    (uint256 excess, uint256 dearth) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(dearth, 0, 'Unexpected dearth of GHO');

    GHO_GSM_4626.grantRole(GSM_CONFIGURATOR_ROLE, ALICE);

    // Cut price of the underlying in half to simulate a loss in underlying value
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE / 2,
      address(USDC_4626_TOKEN),
      6
    );
    vm.prank(ALICE);
    GHO_GSM_4626.updatePriceStrategy(address(newPriceStrategy));

    vm.expectRevert('AMOUNT_EXCEEDS_DEARTH');
    GHO_GSM_4626.backWith(address(GHO_TOKEN), (DEFAULT_GSM_GHO_AMOUNT / 2) + 1);
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

    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit FeesDistributedToTreasury(
      TREASURY,
      address(GHO_TOKEN),
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626))
    );
    GHO_GSM_4626.distributeFeesToTreasury();
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      0,
      'Unexpected GSM GHO balance post-distribution'
    );
    assertEq(GHO_TOKEN.balanceOf(TREASURY), fee, 'Unexpected GHO balance in treasury');
  }
}

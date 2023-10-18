// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsm4626Edge is TestGhoBase {
  using PercentageMath for uint256;

  function testOngoingExposureSellAsset() public {
    (, uint256 ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, 0);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), 0);
    assertEq(USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))), 0);
    assertEq(GHO_GSM_4626.getAvailableUnderlyingExposure(), DEFAULT_GSM_USDC_EXPOSURE);
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), 0);

    uint128 sellAssetAmount = 100e6;
    uint256 calcGhoMinted = 100e18;
    uint256 calcExposure = 100e6;
    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, sellAssetAmount);

    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, calcGhoMinted);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), sellAssetAmount);
    assertEq(
      GHO_GSM_4626.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - calcExposure
    );
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), calcExposure);
    assertEq(
      USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))),
      sellAssetAmount
    );

    // Inflate exchange rate
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, sellAssetAmount, true);

    // same exposure
    assertEq(ghoLevel, calcGhoMinted);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), calcExposure);
    assertEq(
      GHO_GSM_4626.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - calcExposure
    );
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), calcExposure);
    assertEq(
      USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))),
      sellAssetAmount * 2
    );

    // more GHO minted with same amount sold
    uint256 ghoAmountBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 ghoReceived = ghoAmountBefore;

    calcGhoMinted += 100e18 * 2;
    calcExposure += 100e6;
    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, sellAssetAmount);

    uint256 ghoAmountAfter = GHO_TOKEN.balanceOf(ALICE) - ghoAmountBefore;
    assertEq(ghoAmountAfter, ghoReceived * 2);

    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, calcGhoMinted);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), calcExposure);
    assertEq(
      GHO_GSM_4626.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - calcExposure
    );
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), calcExposure);
    assertEq(
      USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))),
      sellAssetAmount * 2 * 2
    );

    // Deflate exchange rate
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, sellAssetAmount * 3, false);

    // same exposure
    assertEq(ghoLevel, calcGhoMinted);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), calcExposure);
    assertEq(
      GHO_GSM_4626.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - calcExposure
    );
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), calcExposure);
    assertEq(
      USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))),
      sellAssetAmount
    );

    // less GHO minted with same amount sold
    ghoAmountBefore = GHO_TOKEN.balanceOf(ALICE);

    calcGhoMinted += 100e18 * 2;
    calcExposure += 100e6;
    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, sellAssetAmount);

    ghoAmountAfter = GHO_TOKEN.balanceOf(ALICE) - ghoAmountBefore;
    assertEq(ghoAmountAfter, ghoReceived / 2);
  }

  function testSellAssetWithHighExchangeRate() public {
    uint256 resultingAssets = DEFAULT_GSM_USDC_AMOUNT * 2;
    uint256 grossAmount = DEFAULT_GSM_GHO_AMOUNT * 2;
    uint256 fee = grossAmount.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = grossAmount - fee;

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    // Inflate exchange rate
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_AMOUNT, true);
    assertEq(USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(ALICE)), resultingAssets);

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, grossAmount, fee);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
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

  function testSellAssetWithLowExchangeRate() public {
    uint256 resultingAssets = DEFAULT_GSM_USDC_AMOUNT / 2;
    uint256 grossAmount = DEFAULT_GSM_GHO_AMOUNT / 2;
    uint256 fee = grossAmount.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = grossAmount - fee;

    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    // Deflate exchange rate
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_AMOUNT / 2, false);
    assertEq(USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(ALICE)), resultingAssets);

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, grossAmount, fee);
    GHO_GSM_4626.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
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

  function testExposureLimitWithSharpExchangeRate() public {
    Gsm4626 gsm = new Gsm4626(address(GHO_TOKEN), address(USDC_4626_TOKEN));
    gsm.initialize(
      address(this),
      TREASURY,
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY),
      DEFAULT_GSM_USDC_EXPOSURE - 1
    );
    GHO_TOKEN.addFacilitator(address(gsm), 'GSM Modified Exposure Cap', DEFAULT_CAPACITY);

    uint128 depositAmount = DEFAULT_GSM_USDC_EXPOSURE / 2;
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, depositAmount);

    // Inflate exchange rate
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, depositAmount, true);
    assertEq(
      USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(ALICE)),
      DEFAULT_GSM_USDC_EXPOSURE
    );

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(gsm), depositAmount);
    gsm.sellAsset(depositAmount, ALICE);
    assertEq(gsm.getAvailableLiquidity(), depositAmount);
    assertEq(gsm.getAvailableUnderlyingExposure(), DEFAULT_GSM_USDC_EXPOSURE - 1 - depositAmount);
    vm.stopPrank();
  }

  function testRevertExposureWithSharpExchangeRate() public {
    Gsm4626 gsm = new Gsm4626(address(GHO_TOKEN), address(USDC_4626_TOKEN));
    gsm.initialize(
      address(this),
      TREASURY,
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY),
      DEFAULT_GSM_USDC_EXPOSURE - 1
    );
    GHO_TOKEN.addFacilitator(address(gsm), 'GSM Modified Exposure Cap', DEFAULT_CAPACITY);

    uint128 depositAmount = DEFAULT_GSM_USDC_EXPOSURE * 2;
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, depositAmount);

    // Deflate exchange rate
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_EXPOSURE, false);
    assertEq(
      USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(ALICE)),
      DEFAULT_GSM_USDC_EXPOSURE
    );

    vm.prank(ALICE);
    vm.expectRevert('EXOGENOUS_ASSET_EXPOSURE_TOO_HIGH');
    gsm.sellAsset(depositAmount, ALICE);
  }

  function testDistributeYieldToTreasury() public {
    /**
     * 1. Alice sellAsset with 1:1 exchangeRate
     * 2. ExchangeRate increases, so there is an excess of backing
     * 3. Distribute GHO fees to treasury, which redirect excess yield in form of GHO too
     */

    uint256 grossAmount = DEFAULT_GSM_GHO_AMOUNT;
    uint256 fee = grossAmount.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = grossAmount - fee;

    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    assertEq(GHO_GSM_4626.getAccruedFees(), fee, 'Unexpected GSM accrued fees');

    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
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

    uint256 backingBefore = USDC_4626_TOKEN.previewRedeem(
      USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))
    );

    // Inflate exchange rate
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_AMOUNT, true);
    // Accrued dees does not change
    assertEq(GHO_GSM_4626.getAccruedFees(), fee, 'Unexpected GSM accrued fees');

    // Same underlying exposure
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

    // More backing than before
    uint256 backingAfter = USDC_4626_TOKEN.previewRedeem(
      USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))
    );
    assertEq(backingAfter, backingBefore * 2);

    // Distribute fees and yield in form of GHO to the treasury
    uint256 totalBackedGho = GHO_GSM_4626_FIXED_PRICE_STRATEGY.getAssetPriceInGho(
      GHO_GSM_4626.getAvailableLiquidity()
    );
    (, uint256 totalMintedGho) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(totalBackedGho, totalMintedGho + DEFAULT_GSM_GHO_AMOUNT);

    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit FeesDistributedToTreasury(
      TREASURY,
      address(GHO_TOKEN),
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)) + DEFAULT_GSM_GHO_AMOUNT
    );

    // Accrued fees does not change, only upon swap action or distribution of fees
    assertEq(GHO_GSM_4626.getAccruedFees(), fee, 'Unexpected GSM accrued fees');

    GHO_GSM_4626.distributeFeesToTreasury();

    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      0,
      'Unexpected GSM GHO balance post-distribution'
    );
    assertEq(GHO_GSM_4626.getAccruedFees(), 0, 'Unexpected GSM accrued fees');
    assertEq(
      GHO_TOKEN.balanceOf(TREASURY),
      fee + DEFAULT_GSM_GHO_AMOUNT,
      'Unexpected GHO balance in treasury'
    );

    (, totalMintedGho) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(
      totalBackedGho,
      GHO_GSM_4626_FIXED_PRICE_STRATEGY.getAssetPriceInGho(GHO_GSM_4626.getAvailableLiquidity())
    );
    assertEq(totalBackedGho, totalMintedGho);
  }

  function testDistributeYieldToTreasuryDoNothing() public {
    uint256 gsmBalanceBefore = GHO_TOKEN.balanceOf(address(GHO_GSM_4626));
    uint256 treasuryBalanceBefore = GHO_TOKEN.balanceOf(address(TREASURY));
    assertEq(GHO_GSM_4626.getAccruedFees(), 0, 'Unexpected GSM accrued fees');

    GHO_GSM_4626.distributeFeesToTreasury();

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

  function testDistributeYieldToTreasuryWithNoExcess() public {
    /**
     * 1. Alice sellAsset with 1:1 exchangeRate
     * 2. Distribute GHO fees to treasury, but there is no yield from excess backing
     */

    uint256 grossAmount = DEFAULT_GSM_GHO_AMOUNT;
    uint256 fee = grossAmount.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = grossAmount - fee;

    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    assertEq(GHO_GSM_4626.getAccruedFees(), fee, 'Unexpected GSM accrued fees');

    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
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

    // Distribute fees, with no yield in GHO to redirect
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit FeesDistributedToTreasury(
      TREASURY,
      address(GHO_TOKEN),
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626))
    );
    uint256 totalBackedGho = GHO_GSM_4626_FIXED_PRICE_STRATEGY.getAssetPriceInGho(
      GHO_GSM_4626.getAvailableLiquidity()
    );
    (, uint256 totalMintedGho) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(totalBackedGho, totalMintedGho);

    GHO_GSM_4626.distributeFeesToTreasury();

    assertEq(GHO_GSM_4626.getAccruedFees(), 0, 'Unexpected GSM accrued fees');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      0,
      'Unexpected GSM GHO balance post-distribution'
    );
    assertEq(GHO_TOKEN.balanceOf(TREASURY), fee, 'Unexpected GHO balance in treasury');

    (, totalMintedGho) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(totalBackedGho, totalMintedGho);
  }

  function testDistributeYieldToTreasuryWithLosses() public {
    /**
     * 1. Alice sellAsset with 1:1 exchangeRate
     * 2. ExchangeRate decreases, so there is a loss
     * 3. Distribute of GHO fees only
     * 4. Portion of minted GHO unbacked
     */

    uint256 grossAmount = DEFAULT_GSM_GHO_AMOUNT;
    uint256 fee = grossAmount.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = grossAmount - fee;

    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    assertEq(GHO_GSM_4626.getAccruedFees(), fee, 'Unexpected GSM accrued fees');

    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
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

    uint256 backingBefore = USDC_4626_TOKEN.previewRedeem(
      USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))
    );

    // Deflate exchange rate
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_AMOUNT / 2, false);
    assertEq(
      USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))),
      DEFAULT_GSM_USDC_AMOUNT / 2
    );
    // Accrued fees does not change
    assertEq(GHO_GSM_4626.getAccruedFees(), fee, 'Unexpected GSM accrued fees');

    // Same underlying exposure
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

    // Less backing than before
    uint256 backingAfter = USDC_4626_TOKEN.previewRedeem(
      USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))
    );
    assertEq(backingAfter, backingBefore / 2);

    // Distribute fees
    uint256 totalBackedGho = GHO_GSM_4626_FIXED_PRICE_STRATEGY.getAssetPriceInGho(
      GHO_GSM_4626.getAvailableLiquidity()
    );
    (, uint256 totalMintedGho) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(totalBackedGho, totalMintedGho / 2);

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
    assertEq(totalBackedGho, totalMintedGho / 2);
  }

  function testGetAccruedFeesWithHighExchangeRate() public {
    /**
     * 1. Alice sellAsset with 1:1 exchangeRate
     * 2. ExchangeRate increases, so there is an excess of backing
     * 3. Accrued fees does not factor in new yield in form of GHO
     * 4. A new sellAsset does not accrue fees from yield (only the swap fee)
     * 5. A new buyAsset accrues fees from the swap fee and yield
     * 6. The distribution of fees does not add new fees
     */
    uint256 ongoingAccruedFees = 0;

    uint256 grossAmount = DEFAULT_GSM_GHO_AMOUNT;
    uint256 sellFee = grossAmount.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = grossAmount - sellFee;

    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    ongoingAccruedFees += sellFee;
    assertEq(GHO_GSM_4626.getAccruedFees(), ongoingAccruedFees, 'Unexpected GSM accrued fees');

    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoOut, 'Unexpected final GHO balance');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      ongoingAccruedFees,
      'Unexpected GSM GHO balance'
    );
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

    // Inflate exchange rate
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_AMOUNT, true);
    // Accrued dees does not change
    assertEq(GHO_GSM_4626.getAccruedFees(), ongoingAccruedFees, 'Unexpected GSM accrued fees');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      ongoingAccruedFees,
      'Unexpected GSM GHO balance'
    );

    // Yield in form of GHO, not accrued yet
    uint256 totalBackedGho = GHO_GSM_4626_FIXED_PRICE_STRATEGY.getAssetPriceInGho(
      GHO_GSM_4626.getAvailableLiquidity()
    );
    (, uint256 totalMintedGho) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    uint256 yieldInGho = totalBackedGho - totalMintedGho;
    assertEq(yieldInGho, DEFAULT_GSM_GHO_AMOUNT);

    // Sell asset accrues only the swap fee
    grossAmount = DEFAULT_GSM_GHO_AMOUNT * 2; // taking exchange rate into account
    sellFee = grossAmount.percentMul(DEFAULT_GSM_SELL_FEE);
    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    ongoingAccruedFees += sellFee;
    assertEq(GHO_GSM_4626.getAccruedFees(), ongoingAccruedFees, 'Unexpected GSM accrued fees');

    // Buy asset accrues only the swap fee
    grossAmount = DEFAULT_GSM_GHO_AMOUNT * 2; // taking exchange rate into account
    uint256 buyFee = grossAmount.percentMul(DEFAULT_GSM_BUY_FEE);
    ghoFaucet(BOB, grossAmount + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM_4626), grossAmount + buyFee);
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    ongoingAccruedFees += buyFee + yieldInGho;
    assertEq(GHO_GSM_4626.getAccruedFees(), ongoingAccruedFees, 'Unexpected GSM accrued fees');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      ongoingAccruedFees,
      'Unexpected GSM GHO balance'
    );

    // Fee distribution
    uint256 treasuryBalanceBefore = GHO_TOKEN.balanceOf(address(TREASURY));
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit FeesDistributedToTreasury(TREASURY, address(GHO_TOKEN), ongoingAccruedFees);
    GHO_GSM_4626.distributeFeesToTreasury();

    assertEq(GHO_GSM_4626.getAccruedFees(), 0, 'Unexpected GSM accrued fees3');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM_4626)), 0, 'Unexpected GSM GHO balance');
    assertEq(
      GHO_TOKEN.balanceOf(address(TREASURY)) - treasuryBalanceBefore,
      ongoingAccruedFees,
      'Unexpected Treasury GHO balance'
    );
  }

  function testGetAccruedFeesWithHighExchangeRateAndMaxedOutCapacity() public {
    /**
     * 1. Alice sellAsset with 1:1 exchangeRate
     * 2. ExchangeRate increases, so there is an excess of backing
     * 3. Accrued fees does not factor in new yield in form of GHO
     * 4. A new sellAsset does not accrue fees from yield (only the swap fee)
     * 5. Bucket capacity is set to 0, so yield in form of GHO cannot be minted
     * 6. The distribution of fees does not accrue fees from yield in form of GHO
     */
    uint256 ongoingAccruedFees = 0;

    uint256 grossAmount = DEFAULT_GSM_GHO_AMOUNT;
    uint256 sellFee = grossAmount.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = grossAmount - sellFee;

    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    ongoingAccruedFees += sellFee;
    assertEq(GHO_GSM_4626.getAccruedFees(), ongoingAccruedFees, 'Unexpected GSM accrued fees');

    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoOut, 'Unexpected final GHO balance');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      ongoingAccruedFees,
      'Unexpected GSM GHO balance'
    );
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

    // Inflate exchange rate
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_AMOUNT, true);
    // Accrued dees does not change
    assertEq(GHO_GSM_4626.getAccruedFees(), ongoingAccruedFees, 'Unexpected GSM accrued fees');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM_4626)),
      ongoingAccruedFees,
      'Unexpected GSM GHO balance'
    );

    // Yield in form of GHO, not accrued yet
    uint256 totalBackedGho = GHO_GSM_4626_FIXED_PRICE_STRATEGY.getAssetPriceInGho(
      GHO_GSM_4626.getAvailableLiquidity()
    );
    (, uint256 totalMintedGho) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    uint256 yieldInGho = totalBackedGho - totalMintedGho;
    assertEq(yieldInGho, DEFAULT_GSM_GHO_AMOUNT);

    // Sell asset accrues only the swap fee
    grossAmount = DEFAULT_GSM_GHO_AMOUNT * 2; // taking exchange rate into account
    sellFee = grossAmount.percentMul(DEFAULT_GSM_SELL_FEE);
    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
    ongoingAccruedFees += sellFee;
    assertEq(GHO_GSM_4626.getAccruedFees(), ongoingAccruedFees, 'Unexpected GSM accrued fees');

    // Bucket capacity of GSM set to 0 so no more GHO can be minted (including yield in form of GHO)
    GHO_TOKEN.setFacilitatorBucketCapacity(address(GHO_GSM_4626), 0);

    // Fee distribution
    uint256 treasuryBalanceBefore = GHO_TOKEN.balanceOf(address(TREASURY));
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit FeesDistributedToTreasury(TREASURY, address(GHO_TOKEN), ongoingAccruedFees);
    GHO_GSM_4626.distributeFeesToTreasury();

    assertEq(GHO_GSM_4626.getAccruedFees(), 0, 'Unexpected GSM accrued fees3');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM_4626)), 0, 'Unexpected GSM GHO balance');
    assertEq(
      GHO_TOKEN.balanceOf(address(TREASURY)) - treasuryBalanceBefore,
      ongoingAccruedFees,
      'Unexpected Treasury GHO balance'
    );
  }

  function testBuyAssetAfterHighExchangeRate() public {
    /**
     * 1. Alice sellAsset with 1:1 exchangeRate
     * 2. Exchange rate increases, there is an excess of underlying backing GHO
     * 3. Alice buyAsset of the current exposure. There is a mint of GHO before the action so the level is updated.
     */

    (, uint256 ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, 0);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), 0);
    assertEq(USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))), 0);
    assertEq(GHO_GSM_4626.getAvailableUnderlyingExposure(), DEFAULT_GSM_USDC_EXPOSURE);
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), 0);

    uint128 sellAssetAmount = DEFAULT_GSM_USDC_AMOUNT;
    uint256 calcGhoMinted = DEFAULT_GSM_GHO_AMOUNT;
    uint256 calcExposure = DEFAULT_GSM_USDC_AMOUNT;
    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, sellAssetAmount);

    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, calcGhoMinted);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), sellAssetAmount);
    assertEq(
      GHO_GSM_4626.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - calcExposure
    );
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), calcExposure);
    assertEq(
      USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))),
      sellAssetAmount
    );

    // Inflate exchange rate
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, sellAssetAmount, true);

    assertEq(ghoLevel, calcGhoMinted);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), calcExposure);
    assertEq(
      GHO_GSM_4626.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - calcExposure
    );
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), calcExposure);
    assertEq(
      USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))),
      sellAssetAmount * 2
    );

    // Top up Alice with GHO
    ghoFaucet(ALICE, 1_000_000e18);

    // Alice buy all assets and there is a mint of GHO backed by excess of underlying before the action
    vm.startPrank(ALICE);
    GHO_TOKEN.approve(address(GHO_GSM_4626), type(uint256).max);

    uint256 totalBackedGho = GHO_GSM_4626_FIXED_PRICE_STRATEGY.getAssetPriceInGho(
      GHO_GSM_4626.getAvailableLiquidity()
    );
    (, uint256 totalMintedGho) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(totalBackedGho, totalMintedGho + DEFAULT_GSM_GHO_AMOUNT);

    calcGhoMinted = 0;
    calcExposure = 0;
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, calcGhoMinted);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), calcExposure);
    assertEq(
      GHO_GSM_4626.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - calcExposure
    );
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), calcExposure);
    assertEq(USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))), 0);
  }

  function testBuyAssetAfterLowExchangeRate() public {
    /**
     * 1. Alice sellAsset with 1:1 exchangeRate
     * 2. Exchange rate decreases, there is a portion of GHO unbacked
     * 3. Alice buyAsset of the current exposure
     * 4. Exposure is 0 but level is not 0, so there is unbacked GHO
     */

    (, uint256 ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, 0);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), 0);
    assertEq(USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))), 0);
    assertEq(GHO_GSM_4626.getAvailableUnderlyingExposure(), DEFAULT_GSM_USDC_EXPOSURE);
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), 0);

    uint128 sellAssetAmount = DEFAULT_GSM_USDC_AMOUNT;
    uint256 calcGhoMinted = DEFAULT_GSM_GHO_AMOUNT;
    uint256 calcExposure = DEFAULT_GSM_USDC_AMOUNT;
    _sellAsset(GHO_GSM_4626, USDC_4626_TOKEN, USDC_TOKEN, ALICE, sellAssetAmount);

    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, calcGhoMinted);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), sellAssetAmount);
    assertEq(
      GHO_GSM_4626.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - calcExposure
    );
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), calcExposure);
    assertEq(
      USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))),
      sellAssetAmount
    );

    // Deflate exchange rate
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, DEFAULT_GSM_USDC_AMOUNT / 2, false);

    assertEq(ghoLevel, calcGhoMinted);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), calcExposure);
    assertEq(
      GHO_GSM_4626.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - calcExposure
    );
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), calcExposure);
    assertEq(
      USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))),
      sellAssetAmount / 2
    );

    // Top up Alice with GHO
    ghoFaucet(ALICE, 1_000_000e18);

    // Buy all assets
    vm.startPrank(ALICE);
    calcGhoMinted = DEFAULT_GSM_GHO_AMOUNT / 2;
    calcExposure = 0;
    GHO_TOKEN.approve(address(GHO_GSM_4626), type(uint256).max);
    GHO_GSM_4626.buyAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    // 0 exposure, but non-zero level
    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertTrue(ghoLevel != 0);
    assertEq(ghoLevel, calcGhoMinted);
    assertEq(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626)), calcExposure);
    assertEq(
      GHO_GSM_4626.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - calcExposure
    );
    assertEq(GHO_GSM_4626.getAvailableLiquidity(), calcExposure);
    assertEq(USDC_4626_TOKEN.previewRedeem(USDC_4626_TOKEN.balanceOf(address(GHO_GSM_4626))), 0);
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
    (uint256 excess, uint256 deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, (DEFAULT_GSM_USDC_EXPOSURE / 4) * 1e12, 'Unexpected excess');
    assertEq(deficit, 0, 'Unexpected non-zero deficit');
    uint128 buyAmount = DEFAULT_CAPACITY / (((5 * DEFAULT_GSM_USDC_EXPOSURE) / 4) / 100);

    vm.startPrank(ALICE);
    GHO_TOKEN.approve(address(GHO_GSM_4626), DEFAULT_CAPACITY);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit BuyAsset(ALICE, ALICE, buyAmount, DEFAULT_CAPACITY, 0);
    GHO_GSM_4626.buyAsset(buyAmount, ALICE);
    vm.stopPrank();

    assertEq(USDC_4626_TOKEN.balanceOf(ALICE), buyAmount, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), 0, 'Unexpected final GHO balance');

    // Ensure GHO level is at 0, but that excess is unchanged
    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, 0, 'Unexpected GHO bucket level after initial sell');
    (excess, deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, (DEFAULT_GSM_USDC_EXPOSURE / 4) * 1e12, 'Unexpected excess');
    assertEq(deficit, 0, 'Unexpected non-zero deficit');

    vm.startPrank(ALICE);
    USDC_4626_TOKEN.approve(address(GHO_GSM_4626), 1);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit SellAsset(ALICE, ALICE, 1, 1e12, 0);
    GHO_GSM_4626.sellAsset(1, ALICE);
    vm.stopPrank();

    // Ensure GHO level is at 1e12, but that excess is unchanged
    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(ghoLevel, 1e12, 'Unexpected GHO bucket level after initial sell');
    (excess, deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, (DEFAULT_GSM_USDC_EXPOSURE / 4) * 1e12, 'Unexpected excess');
    assertEq(deficit, 0, 'Unexpected non-zero deficit');

    vm.startPrank(ALICE);
    GHO_TOKEN.approve(address(GHO_GSM_4626), 1e12);
    vm.expectEmit(true, true, true, true, address(GHO_GSM_4626));
    emit BuyAsset(ALICE, ALICE, 1, 1e12, 0);
    GHO_GSM_4626.buyAsset(1, ALICE);
    vm.stopPrank();

    // Ensure GHO level is at the previous amount of excess, and excess is now 0
    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM_4626));
    assertEq(
      ghoLevel,
      (DEFAULT_GSM_USDC_EXPOSURE / 4) * 1e12,
      'Unexpected GHO bucket level after final buy'
    );
    (excess, deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess');
    assertEq(deficit, 0, 'Unexpected non-zero deficit');
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
    (uint256 excess, uint256 deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, (DEFAULT_GSM_USDC_EXPOSURE / 4) * 1e12, 'Unexpected excess');
    assertEq(deficit, 0, 'Unexpected non-zero deficit');

    // // Change the Price Strategy to the same fixed price, to trigger the update and yield accrual
    vm.expectEmit(true, true, false, true, address(GHO_GSM_4626));
    emit PriceStrategyUpdated(
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY),
      address(GHO_GSM_4626_FIXED_PRICE_STRATEGY)
    );
    GHO_GSM_4626.updatePriceStrategy(address(GHO_GSM_4626_FIXED_PRICE_STRATEGY));

    // Ensure excess and deficit are the same
    (excess, deficit) = GHO_GSM_4626.getCurrentBacking();
    assertEq(excess, (DEFAULT_GSM_USDC_EXPOSURE / 4) * 1e12, 'Unexpected excess');
    assertEq(deficit, 0, 'Unexpected non-zero deficit');
  }
}

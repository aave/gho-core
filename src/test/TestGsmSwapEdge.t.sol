// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmSwapEdge is TestGhoBase {
  using PercentageMath for uint256;
  using PercentageMath for uint128;

  /**
   * @dev Edge case where it is not possible to burn all GHO minted due to rounding issues.
   * e.g. With (1e16 + 1) priceRatio, a user gets 1e11 gho for selling 1 asset but gets 1 asset by selling 1e11+1 gho
   */
  function testCannotBuyAllUnderlying() public {
    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', 5, FAUCET);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      10000000000000001, // 1e16 + 1
      address(newToken),
      5
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, type(uint128).max, address(GHO_RESERVE));
    GHO_RESERVE.addEntity(address(gsm));
    GHO_RESERVE.setLimit(address(gsm), type(uint256).max);

    // Sell 2 assets for 2e11 GHO
    vm.prank(FAUCET);
    newToken.mint(ALICE, 2);

    vm.startPrank(ALICE);
    newToken.approve(address(gsm), 2);
    gsm.sellAsset(2, ALICE);
    vm.stopPrank();

    // Top up with GHO
    (, uint256 estGhoBought, , ) = gsm.getGhoAmountForBuyAsset(2);
    ghoFaucet(ALICE, estGhoBought * 20);

    vm.startPrank(ALICE);
    GHO_TOKEN.approve(address(gsm), type(uint256).max);

    // Try to buy all, which is 2 assets for 2e11+1 GHO
    uint256 allUnderlying = gsm.getAvailableLiquidity();
    vm.expectRevert();
    gsm.buyAsset(allUnderlying, ALICE);

    // Buy a portion
    uint256 userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 userAssetBefore = newToken.balanceOf(ALICE);

    (uint256 exactAssetAmount, uint256 exactGhoAmount) = gsm.buyAsset(1, ALICE);

    assertEq(
      newToken.balanceOf(ALICE) - userAssetBefore,
      exactAssetAmount,
      'unexpected underlying balance of ALICE'
    );
    assertEq(
      userGhoBefore - GHO_TOKEN.balanceOf(ALICE),
      exactGhoAmount,
      'unexpected GHO balance of ALICE'
    );

    assertTrue(gsm.getAvailableLiquidity() > 0, 'unexpected remaining liquidity');
    vm.stopPrank();
  }

  /**
   * @dev Edge case where it is not possible to sell less than the minimum amount because would lead to 0 GHO.
   */
  function testGetAssetAmountForSellAssetBelowMinimumAmount() public {
    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', 18, FAUCET);
    FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(4900, 4900);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE,
      address(newToken),
      18
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, 100_000_000e18, address(GHO_RESERVE));
    gsm.updateFeeStrategy(address(newFeeStrategy));
    GHO_RESERVE.addEntity(address(gsm));
    GHO_RESERVE.setLimit(address(gsm), 100_000_000 ether);

    // Get asset amount required to receive 1 GHO
    (uint256 assetAmount, uint256 ghoBought, uint256 grossAmount, uint256 fee) = gsm
      .getAssetAmountForSellAsset(1);

    assertEq(assetAmount, 2, 'Unexpected asset to sell');
    assertEq(ghoBought, 1, 'Unexpected gho amount bought');
    assertEq(grossAmount, 2, 'Unexpected gross amount');
    assertEq(fee, 1, 'Unexpected fee');

    // Using 1 wei less than the assetAmount will round down the asset amount to 0, so should revert
    vm.expectRevert('INVALID_AMOUNT');
    gsm.sellAsset(assetAmount - 1, ALICE);

    _sellAsset(gsm, newToken, ALICE, assetAmount);
    assertEq(GHO_TOKEN.balanceOf(ALICE), 1, 'Unexpected GHO balance');
  }

  /**
   * @dev Sell asset function meets the maximum amount to be sold and does not over-charge the user.
   * e.g. if the GSM can provide 10 GHO for 12 assets, it charges only 12 even if the user provides more than 12.
   */
  function testSellAssetWithMinimumAmount() public {
    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', 18, FAUCET);
    FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(3000, 3000);
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE,
      address(newToken),
      18
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(address(this), TREASURY, 100_000_000e18, address(GHO_RESERVE));
    gsm.updateFeeStrategy(address(newFeeStrategy));
    GHO_RESERVE.addEntity(address(gsm));
    GHO_RESERVE.setLimit(address(gsm), 100_000_000 ether);

    // Get asset amount required to receive 10000 GHO
    (uint256 assetAmount, uint256 ghoBought, uint256 grossAmount, uint256 fee) = gsm
      .getAssetAmountForSellAsset(10000);

    assertEq(assetAmount, 14286, 'Unexpected asset to sell');
    assertEq(ghoBought, 10000, 'Unexpected gho amount bought');
    assertEq(grossAmount, 14286, 'Unexpected gross amount');
    assertEq(fee, 4286, 'Unexpected fee');

    assertEq(newToken.balanceOf(ALICE), 0, 'Unexpected asset amount before');

    // Mint 1 more asset than required (14286) to receive 10000 GHO
    vm.prank(FAUCET);
    newToken.mint(ALICE, assetAmount + 1);

    vm.startPrank(ALICE);
    newToken.approve(address(gsm), assetAmount);
    // Sell 1 more asset than required to receive 10000 GHO
    gsm.sellAsset(assetAmount + 1, ALICE);
    vm.stopPrank();
    assertEq(GHO_TOKEN.balanceOf(ALICE), 10000, 'Unexpected GHO balance');
    // Should have 1 "leftover" asset, as sellAsset prevents "overpaying" so only assetAmount spent
    assertEq(newToken.balanceOf(ALICE), 1, 'Unexpected ending asset amount');
  }

  /**
   * @dev Checks sellAsset does not charge more asset than needed
   * in case the underlying asset has more decimals than GHO (18)
   */
  function testSellAssetWithHigherDecimals() public {
    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', 24, FAUCET);
    vm.prank(FAUCET);
    newToken.mint(ALICE, 1_000_000e24);

    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(newToken),
      24 // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(ALICE, TREASURY, 1_000_000e24, address(GHO_RESERVE));
    GHO_RESERVE.addEntity(address(gsm));
    GHO_RESERVE.setLimit(address(gsm), 100_000_000 ether);

    vm.startPrank(ALICE);
    newToken.approve(address(gsm), type(uint256).max);

    // Less than 1e6 results in 0 GHO
    vm.expectRevert('INVALID_AMOUNT');
    gsm.sellAsset(0.9e6, ALICE);

    // Lowest amount that can be sold is 1e6
    uint256 userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 userAssetBefore = newToken.balanceOf(ALICE);

    gsm.sellAsset(1e6, ALICE);

    assertEq(GHO_TOKEN.balanceOf(ALICE) - userGhoBefore, 1, 'unexpected amount of GHO purchased');
    assertEq(userAssetBefore - newToken.balanceOf(ALICE), 1e6, 'unexpected amount of asset sold');

    // It does not overcharge in case of non-divisible amount of assets
    userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    userAssetBefore = newToken.balanceOf(ALICE);

    (uint256 assetAmount, uint256 ghoBought) = gsm.sellAsset(1.9e6, ALICE);

    assertEq(GHO_TOKEN.balanceOf(ALICE) - userGhoBefore, 1, 'unexpected amount of GHO purchased');
    assertEq(ghoBought, 1, 'unexpected amount of returned GHO purchased');
    assertEq(assetAmount, 1e6, 'Unexpected asset amount sold');
    assertEq(userAssetBefore - newToken.balanceOf(ALICE), 1e6, 'unexpected amount of asset sold');

    vm.stopPrank();
  }

  /**
   * @dev Checks buyAsset does not provide more asset than the corresponding to the
   * gho amount charged, in case the underlying asset has more decimals than GHO (18)
   */
  function testBuyAssetWithHigherDecimals() public {
    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', 24, FAUCET);
    vm.prank(FAUCET);
    newToken.mint(ALICE, 1_000_000e24);
    ghoFaucet(ALICE, DEFAULT_CAPACITY);

    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(newToken),
      24 // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(ALICE, TREASURY, 1_000_000e24, address(GHO_RESERVE));
    GHO_RESERVE.addEntity(address(gsm));
    GHO_RESERVE.setLimit(address(gsm), 100_000_000 ether);

    vm.startPrank(ALICE);
    // Alice sells some asset to the GSM
    newToken.approve(address(gsm), type(uint256).max);
    GHO_TOKEN.approve(address(gsm), type(uint256).max);
    gsm.sellAsset(1_000_000e24, ALICE);

    // The minimum amount of assets that can be bought is 1e6, and the contract recalculates
    // the corresponding amount of assets to the exact GHO burned.
    // User buys more asset than it should due to price conversion
    uint256 userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 userAssetBefore = newToken.balanceOf(ALICE);

    (uint256 assetAmount, uint256 ghoSold) = gsm.buyAsset(1.9e6, ALICE); // should by just 1e6 asset in exchange of 1 GHO

    assertEq(userGhoBefore - GHO_TOKEN.balanceOf(ALICE), 2, 'unexpected amount of GHO spent');
    assertEq(ghoSold, 2, 'unexpected amount of returned GHO spent');
    assertEq(assetAmount, 2e6, 'Unexpected asset amount bought');
    assertEq(
      newToken.balanceOf(ALICE) - userAssetBefore,
      2e6,
      'unexpected amount of assets purchased'
    );

    vm.stopPrank();
  }

  /**
   * @dev Checks sellAsset function is aligned with getAssetAmountForSellAsset,
   * in case the underlying asset has less decimals than GHO (18)
   */
  function testSellAssetByGhoAmountWithLowerDecimals() public {
    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', 6, FAUCET);
    vm.prank(FAUCET);
    newToken.mint(ALICE, 1_000_000e6);

    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(newToken),
      6 // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(ALICE, TREASURY, 1_000_000e6, address(GHO_RESERVE));
    GHO_RESERVE.addEntity(address(gsm));
    GHO_RESERVE.setLimit(address(gsm), 100_000_000 ether);

    // User wants to know how much asset must sell to get 1.9e12 GHO
    vm.startPrank(ALICE);
    uint256 ghoAmountToGet = 1.9e12; // this is the minimum that must get
    (uint256 estSellAssetAmount, uint256 exactGhoToGet, , ) = gsm.getAssetAmountForSellAsset(
      ghoAmountToGet
    );
    uint256 userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 userAssetBefore = newToken.balanceOf(ALICE);

    newToken.approve(address(gsm), type(uint256).max);
    gsm.sellAsset(estSellAssetAmount, ALICE);

    assertEq(
      GHO_TOKEN.balanceOf(ALICE) - userGhoBefore,
      exactGhoToGet,
      'exact gho amount to get does not match'
    );
    assertGt(
      GHO_TOKEN.balanceOf(ALICE) - userGhoBefore,
      ghoAmountToGet,
      'minimum gho to get not reached'
    );

    assertEq(
      userAssetBefore - newToken.balanceOf(ALICE),
      estSellAssetAmount,
      'sold assets above maximum amount'
    );

    vm.stopPrank();
  }

  /**
   * @dev Checks sellAsset function is aligned with getAssetAmountForSellAsset,
   * in case the underlying asset has more decimals than GHO (18)
   */
  function testSellAssetByGhoAmountWithHigherDecimals() public {
    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', 24, FAUCET);
    vm.prank(FAUCET);
    newToken.mint(ALICE, 1_000_000e24);

    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(newToken),
      24 // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(ALICE, TREASURY, 1_000_000e24, address(GHO_RESERVE));
    GHO_RESERVE.addEntity(address(gsm));
    GHO_RESERVE.setLimit(address(gsm), 100_000_000 ether);

    // User wants to know how much asset must sell to get 1 GHO
    vm.startPrank(ALICE);
    uint256 ghoAmountToGet = 1; // this is the lowest GHO that can be purchased
    (uint256 estSellAssetAmount, uint256 exactGhoToGet, , ) = gsm.getAssetAmountForSellAsset(
      ghoAmountToGet
    );
    uint256 userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 userAssetBefore = newToken.balanceOf(ALICE);

    newToken.approve(address(gsm), type(uint256).max);
    gsm.sellAsset(estSellAssetAmount, ALICE);

    assertEq(
      GHO_TOKEN.balanceOf(ALICE) - userGhoBefore,
      exactGhoToGet,
      'exact gho amount to get does not match'
    );
    assertEq(
      GHO_TOKEN.balanceOf(ALICE) - userGhoBefore,
      ghoAmountToGet,
      'unexpected amount of GHO purchased'
    );
    assertEq(
      userAssetBefore - newToken.balanceOf(ALICE),
      estSellAssetAmount,
      'unexpected amount of asset sold'
    );

    vm.stopPrank();
  }

  /**
   * @dev Checks buyAsset function is aligned with getAssetAmountForBuyAsset,
   * in case the underlying asset has less decimals than GHO (18)
   */
  function testBuyAssetByGhoAmountWithLowerDecimals() public {
    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', 6, FAUCET);
    vm.prank(FAUCET);
    newToken.mint(ALICE, 1_000_000e6);
    ghoFaucet(ALICE, DEFAULT_CAPACITY);

    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(newToken),
      6 // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(ALICE, TREASURY, 1_000_000e6, address(GHO_RESERVE));
    GHO_RESERVE.addEntity(address(gsm));
    GHO_RESERVE.setLimit(address(gsm), 100_000_000 ether);

    vm.startPrank(ALICE);
    // Alice sells some asset to the GSM
    newToken.approve(address(gsm), type(uint256).max);
    gsm.sellAsset(1_000_000e6, ALICE);

    // User wants to know how much asset can buy with 1.9e12 GHO
    uint256 ghoAmountToSpend = 1.9e12; // this is the maximum that can spend
    (uint256 estBuyAssetAmount, uint256 exactGhoSpent, , ) = gsm.getAssetAmountForBuyAsset(
      ghoAmountToSpend
    );
    uint256 userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 userAssetBefore = newToken.balanceOf(ALICE);

    GHO_TOKEN.approve(address(gsm), type(uint256).max);
    gsm.buyAsset(estBuyAssetAmount, ALICE);

    assertTrue(
      userGhoBefore - GHO_TOKEN.balanceOf(ALICE) <= ghoAmountToSpend,
      'gho spend above maximum amount'
    );
    assertEq(userGhoBefore - GHO_TOKEN.balanceOf(ALICE), exactGhoSpent, 'gho spent does not match');
    assertEq(
      newToken.balanceOf(ALICE) - userAssetBefore,
      estBuyAssetAmount,
      'bought assets and amount diff do not match'
    );

    vm.stopPrank();
  }

  /**
   * @dev Checks buyAsset function is aligned with getAssetAmountForBuyAsset,
   * in case the underlying asset has more decimals than GHO (18)
   */
  function testBuyAssetByGhoAmountWithHigherDecimals() public {
    TestnetERC20 newToken = new TestnetERC20('Test Coin', 'TEST', 24, FAUCET);
    vm.prank(FAUCET);
    newToken.mint(ALICE, 1_000_000e24);
    ghoFaucet(ALICE, DEFAULT_CAPACITY);

    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE, // 1e18
      address(newToken),
      24 // decimals
    );
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(newToken), address(newPriceStrategy));
    gsm.initialize(ALICE, TREASURY, 1_000_000e24, address(GHO_RESERVE));
    GHO_RESERVE.addEntity(address(gsm));
    GHO_RESERVE.setLimit(address(gsm), 100_000_000 ether);

    vm.startPrank(ALICE);
    // Alice sells some asset to the GSM
    newToken.approve(address(gsm), type(uint256).max);
    gsm.sellAsset(1_000_000e24, ALICE);

    // User wants to know how much asset can buy with 1 GHO
    uint256 ghoAmountToSpend = 1; // this is the lowest amount that can spend
    (uint256 estBuyAssetAmount, uint256 exactGhoSpent, , ) = gsm.getAssetAmountForBuyAsset(
      ghoAmountToSpend
    );
    uint256 userGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 userAssetBefore = newToken.balanceOf(ALICE);

    GHO_TOKEN.approve(address(gsm), type(uint256).max);
    gsm.buyAsset(estBuyAssetAmount, ALICE);

    assertEq(
      userGhoBefore - GHO_TOKEN.balanceOf(ALICE),
      exactGhoSpent,
      'exact gho spent does not match'
    );
    assertEq(
      userGhoBefore - GHO_TOKEN.balanceOf(ALICE),
      ghoAmountToSpend,
      'unexpected amount of GHO spent'
    );
    assertEq(
      newToken.balanceOf(ALICE) - userAssetBefore,
      estBuyAssetAmount,
      'unexpected amount of assets purchased'
    );

    vm.stopPrank();
  }
}

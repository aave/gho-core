// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmFixedPriceStrategy4626 is TestGhoBase {
  function testConstructor(uint256 ratio, address underlying, uint8 decimals) public {
    vm.assume(ratio > 0);
    decimals = uint8(bound(decimals, 0, 40));

    FixedPriceStrategy4626 strategy = new FixedPriceStrategy4626(ratio, underlying, decimals);
    assertEq(strategy.GHO_DECIMALS(), 18, 'Unexpected GHO decimals');
    assertEq(strategy.PRICE_RATIO(), ratio, 'Unexpected price ratio');
    assertEq(strategy.UNDERLYING_ASSET(), underlying, 'Unexpected underlying asset');
    assertEq(
      strategy.UNDERLYING_ASSET_DECIMALS(),
      decimals,
      'Unexpected underlying asset decimals'
    );
  }

  function testOneToOnePriceRatio() public {
    FixedPriceStrategy4626 strategy = new FixedPriceStrategy4626(1e18, address(USDC_4626_TOKEN), 6);
    uint256 usdcIn = 100e6;
    uint256 ghoOut = 100e18;
    assertEq(strategy.getAssetPriceInGho(usdcIn, true), ghoOut, 'Unexpected asset price in GHO');
    assertEq(strategy.getGhoPriceInAsset(ghoOut, false), usdcIn, 'Unexpected gho price in asset');
  }

  function testOneToTwoPriceRatio() public {
    FixedPriceStrategy4626 strategy = new FixedPriceStrategy4626(2e18, address(USDC_4626_TOKEN), 6);
    uint256 usdcIn = 100e6;
    uint256 ghoOut = 200e18;
    assertEq(strategy.getAssetPriceInGho(usdcIn, true), ghoOut, 'Unexpected asset price in GHO');
    assertEq(strategy.getGhoPriceInAsset(ghoOut, false), usdcIn, 'Unexpected gho price in asset');
  }

  function testTwoToOnePriceRatio() public {
    FixedPriceStrategy4626 strategy = new FixedPriceStrategy4626(
      0.5e18,
      address(USDC_4626_TOKEN),
      6
    );
    uint256 usdcIn = 100e6;
    uint256 ghoOut = 50e18;
    assertEq(strategy.getAssetPriceInGho(usdcIn, true), ghoOut, 'Unexpected asset price in GHO');
    assertEq(strategy.getGhoPriceInAsset(ghoOut, false), usdcIn, 'Unexpected gho price in asset');
  }

  function testRevertZeroPriceRatio() public {
    vm.expectRevert('INVALID_PRICE_RATIO');
    new FixedPriceStrategy4626(0, address(USDC_4626_TOKEN), 6);
  }

  function testPriceFeedHighExchangeRate() public {
    FixedPriceStrategy4626 strategy = new FixedPriceStrategy4626(1e18, address(USDC_4626_TOKEN), 6);
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, 100e6);

    // Inflate exchange rate to 2
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, 100e6, true);

    assertEq(strategy.getAssetPriceInGho(50e6, true), 100e18);
    assertEq(strategy.getGhoPriceInAsset(100e18, true), 50e6);
  }

  function testPriceFeedLowExchangeRate() public {
    FixedPriceStrategy4626 strategy = new FixedPriceStrategy4626(1e18, address(USDC_4626_TOKEN), 6);
    _mintShares(USDC_4626_TOKEN, USDC_TOKEN, ALICE, 100e6);

    // Deflate exchange rate to 1/2
    _changeExchangeRate(USDC_4626_TOKEN, USDC_TOKEN, 50e6, false);

    assertEq(strategy.getAssetPriceInGho(200e6, true), 100e18);
    assertEq(strategy.getGhoPriceInAsset(100e18, true), 200e6);
  }

  function testFuzzingExchangeRate(uint256 ratio, uint8 decimals, uint256 amount) public {
    decimals = uint8(bound(decimals, 1, 40));
    ratio = bound(ratio, 1, type(uint128).max - 1);
    amount = bound(amount, 0, type(uint128).max - 1);

    FixedPriceStrategy4626 strategy = new FixedPriceStrategy4626(
      ratio,
      address(USDC_4626_TOKEN),
      decimals
    );
    uint256 amountInGho = (amount * ratio) / (10 ** decimals);
    assertEq(
      strategy.getAssetPriceInGho(amount, false),
      amountInGho,
      'Unexpected asset price in GHO'
    );
  }
}

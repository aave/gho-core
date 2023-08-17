// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmFixedPriceStrategy4626 is TestGhoBase {
  function testConstructor(uint256 ratio, address underlying, uint8 decimals) public {
    vm.assume(decimals < 40);

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

  function testOneToOneExchangeRate() public {
    FixedPriceStrategy4626 strategy = new FixedPriceStrategy4626(1e18, address(USDC_4626_TOKEN), 6);
    uint256 usdcIn = 100e6;
    uint256 ghoOut = 100e18;
    assertEq(strategy.getAssetPriceInGho(usdcIn), ghoOut, 'Unexpected asset price in GHO');
    assertEq(strategy.getGhoPriceInAsset(ghoOut), usdcIn, 'Unexpected gho price in asset');
  }

  function testOneToTwoExchangeRate() public {
    FixedPriceStrategy4626 strategy = new FixedPriceStrategy4626(2e18, address(USDC_4626_TOKEN), 6);
    uint256 usdcIn = 100e6;
    uint256 ghoOut = 200e18;
    assertEq(strategy.getAssetPriceInGho(usdcIn), ghoOut, 'Unexpected asset price in GHO');
    assertEq(strategy.getGhoPriceInAsset(ghoOut), usdcIn, 'Unexpected gho price in asset');
  }

  function testTwoToOneExchangeRate() public {
    FixedPriceStrategy4626 strategy = new FixedPriceStrategy4626(
      0.5e18,
      address(USDC_4626_TOKEN),
      6
    );
    uint256 usdcIn = 100e6;
    uint256 ghoOut = 50e18;
    assertEq(strategy.getAssetPriceInGho(usdcIn), ghoOut, 'Unexpected asset price in GHO');
    assertEq(strategy.getGhoPriceInAsset(ghoOut), usdcIn, 'Unexpected gho price in asset');
  }

  function testOneToZeroExchangeRate() public {
    FixedPriceStrategy4626 strategy = new FixedPriceStrategy4626(0, address(USDC_4626_TOKEN), 6);
    uint256 usdcIn = 100e6;
    uint256 ghoOut = 0;
    assertEq(strategy.getAssetPriceInGho(usdcIn), ghoOut, 'Unexpected asset price in GHO');
    assertEq(strategy.getGhoPriceInAsset(ghoOut), 0, 'Unexpected gho price in asset');
  }

  function testFuzzingExchangeRate(uint256 ratio, uint8 decimals, uint256 amount) public {
    vm.assume(decimals < 40 && decimals > 0);
    vm.assume(ratio < type(uint128).max);
    vm.assume(amount < type(uint128).max);

    FixedPriceStrategy4626 strategy = new FixedPriceStrategy4626(
      ratio,
      address(USDC_4626_TOKEN),
      decimals
    );
    uint256 amountInGho = (amount * ratio) / (10 ** decimals);
    assertEq(strategy.getAssetPriceInGho(amount), amountInGho, 'Unexpected asset price in GHO');
  }
}

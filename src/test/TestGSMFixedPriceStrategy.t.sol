// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGSMFixedPriceStrategy is TestGhoBase {
  function testConstructor(uint256 ratio, address underlying, uint8 decimals) public {
    vm.assume(decimals < 40);

    FixedPriceStrategy strategy = new FixedPriceStrategy(ratio, underlying, decimals);
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
    FixedPriceStrategy strategy = new FixedPriceStrategy(1e18, address(USDC_TOKEN), 6);
    uint256 usdcIn = 100e6;
    uint256 ghoOut = 100e18;
    assertEq(strategy.getAssetPriceInGho(usdcIn), ghoOut, 'Unexpected asset price in GHO');
    assertEq(strategy.getGhoPriceInAsset(ghoOut), usdcIn, 'Unexpected gho price in asset');
  }

  function testOneToTwoExchangeRate() public {
    FixedPriceStrategy strategy = new FixedPriceStrategy(2e18, address(USDC_TOKEN), 6);
    uint256 usdcIn = 100e6;
    uint256 ghoOut = 200e18;
    assertEq(strategy.getAssetPriceInGho(usdcIn), ghoOut, 'Unexpected asset price in GHO');
    assertEq(strategy.getGhoPriceInAsset(ghoOut), usdcIn, 'Unexpected gho price in asset');
  }

  function testTwoToOneExchangeRate() public {
    FixedPriceStrategy strategy = new FixedPriceStrategy(0.5e18, address(USDC_TOKEN), 6);
    uint256 usdcIn = 100e6;
    uint256 ghoOut = 50e18;
    assertEq(strategy.getAssetPriceInGho(usdcIn), ghoOut, 'Unexpected asset price in GHO');
    assertEq(strategy.getGhoPriceInAsset(ghoOut), usdcIn, 'Unexpected gho price in asset');
  }

  function testOneToZeroExchangeRate() public {
    FixedPriceStrategy strategy = new FixedPriceStrategy(0, address(USDC_TOKEN), 6);
    uint256 usdcIn = 100e6;
    uint256 ghoOut = 0;
    assertEq(strategy.getAssetPriceInGho(usdcIn), ghoOut, 'Unexpected asset price in GHO');
    assertEq(strategy.getGhoPriceInAsset(ghoOut), 0, 'Unexpected gho price in asset');
  }

  function testFuzzingExchangeRate(
    uint256 ratio,
    address underlying,
    uint8 decimals,
    uint256 amount
  ) public {
    vm.assume(decimals < 40 && decimals > 0);
    vm.assume(ratio < type(uint128).max);
    vm.assume(amount < type(uint128).max);

    FixedPriceStrategy strategy = new FixedPriceStrategy(ratio, underlying, decimals);
    uint256 amountInGho = (amount * ratio) / (10 ** decimals);
    assertEq(strategy.getAssetPriceInGho(amount), amountInGho, 'Unexpected asset price in GHO');
  }
}

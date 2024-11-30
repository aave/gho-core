// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmConverterEdge is TestGhoBase {
  function setUp() public {
    USTB_SUBCRIPTION.setUSTBPrice(9.5e8);
  }

  /// @dev test buyAsset with zero fee to simulate errors seen by TokenLogic
  // https://github.com/TokenLogic-com-au/gho-core/pull/6
  // - TL used 4626 GSM with adapter (ie converter)
  // - triggered error: assertEq(GHO_TOKEN.balanceOf(ALICE), DEFAULT_GSM_GHO_AMOUNT, 'Unexpected final GHO balance');
  // Error: Unexpected final GHO balance
  // Error: a == b not satisfied [uint]
  //       Left: 99_999_999_000_000_000_000
  //      Right: 100_000_000_000_000_000_000
  function testSellAssetZeroFee_roundingError() public {
    GHO_USTB_GSM.updateFeeStrategy(address(0));

    // Alice sells USDC for GHO
    // - GSM converter swaps USDC for BUIDL
    // - then BUIDL for GHO with GSM
    // - then return GHO to Alice

    mintUsdc(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    console2.log('GHO_TOKEN.balanceOf(ALICE) %e', GHO_TOKEN.balanceOf(ALICE));

    vm.startPrank(FAUCET);
    // Supply USTB to issuance contract
    USTB_TOKEN.mint(address(USTB_SUBCRIPTION), DEFAULT_GSM_USDC_AMOUNT * 100);
    vm.stopPrank();

    vm.startPrank(ALICE);
    USTB_TOKEN.approve(address(USTB_GSM_CONVERTER), DEFAULT_GSM_USDC_AMOUNT * 100);
    USDC_TOKEN.approve(address(USTB_GSM_CONVERTER), DEFAULT_GSM_USDC_AMOUNT);

    console2.log(
      'USTB_TOKEN.balanceOf(address(GHO_USTB_GSM)) %e',
      USTB_TOKEN.balanceOf(address(GHO_USTB_GSM))
    );

    (uint256 assetAmount, uint256 ghoBought) = USTB_GSM_CONVERTER.sellAsset(
      DEFAULT_GSM_USDC_AMOUNT,
      ALICE
    );
    vm.stopPrank();

    console2.log('------after sellAsset------');
    console2.log('calculated assetAmount %e', assetAmount);
    console2.log('calculated ghoBought %e', ghoBought);
    console2.log('GHO_TOKEN.balanceOf(ALICE) %e', GHO_TOKEN.balanceOf(ALICE));
    console2.log('DEFAULT_GSM_GHO_AMOUNT %e', DEFAULT_GSM_GHO_AMOUNT);
    console2.log(
      'USTB_TOKEN.balanceOf(address(GHO_USTB_GSM)) %e',
      USTB_TOKEN.balanceOf(address(GHO_USTB_GSM))
    );

    // assertEq(GHO_TOKEN.balanceOf(ALICE), DEFAULT_GSM_GHO_AMOUNT, 'Unexpected final GHO balance');
  }

  function mintUsdc(address to, uint256 amount) internal {
    vm.prank(FAUCET);
    USDC_TOKEN.mint(to, amount);
  }
}

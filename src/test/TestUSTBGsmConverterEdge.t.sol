// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmConverterEdge is TestGhoBase {
  function setUp() public {
    setUSTBPrice(1_100_000_000);
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
    GHO_BUIDL_GSM.updateFeeStrategy(address(0));

    // Alice sells USDC for GHO
    // - GSM converter swaps USDC for BUIDL
    // - then BUIDL for GHO with GSM
    // - then return GHO to Alice

    mintUsdc(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    console2.log('GHO_TOKEN.balanceOf(ALICE) %e', GHO_TOKEN.balanceOf(ALICE));

    // vm.startPrank(FAUCET);
    // // Supply BUIDL to issuance contract
    // BUIDL_TOKEN.mint(address(BUIDL_USDC_ISSUANCE), DEFAULT_GSM_USDC_AMOUNT);
    // vm.stopPrank();

    // vm.startPrank(ALICE);
    // USDC_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_USDC_AMOUNT);

    // console2.log(
    //   'BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)) %e',
    //   BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM))
    // );

    // (uint256 assetAmount, uint256 ghoBought) = GSM_CONVERTER.sellAsset(
    //   DEFAULT_GSM_USDC_AMOUNT,
    //   ALICE
    // );
    // vm.stopPrank();

    // console2.log('------after sellAsset------');
    // console2.log('calculated assetAmount %e', assetAmount);
    // console2.log('calculated ghoBought %e', ghoBought);
    // console2.log('GHO_TOKEN.balanceOf(ALICE) %e', GHO_TOKEN.balanceOf(ALICE));
    // console2.log('DEFAULT_GSM_GHO_AMOUNT %e', DEFAULT_GSM_GHO_AMOUNT);
    // console2.log(
    //   'BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)) %e',
    //   BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM))
    // );

    // assertEq(GHO_TOKEN.balanceOf(ALICE), DEFAULT_GSM_GHO_AMOUNT, 'Unexpected final GHO balance');
  }

  function mintUsdc(address to, uint256 amount) internal {
    vm.prank(FAUCET);
    USDC_TOKEN.mint(to, amount);
  }
}

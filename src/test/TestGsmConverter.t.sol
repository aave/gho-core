// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmConverter is TestGhoBase {
  // using PercentageMath for uint256;
  // using PercentageMath for uint128;

  function setUp() public {
    // (gsmSignerAddr, gsmSignerKey) = makeAddrAndKey('gsmSigner');
  }

  function testConstructor() public {
    GsmConverter gsmConverter = new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(BUIDL_USDC_REDEMPTION),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );
    assertTrue(
      gsmConverter.hasRole(gsmConverter.DEFAULT_ADMIN_ROLE(), address(this)),
      'Unexpected default admin address'
    );
    assertEq(gsmConverter.GSM(), address(GHO_BUIDL_GSM), 'Unexpected GSM address');
    assertEq(
      gsmConverter.REDEMPTION_CONTRACT(),
      address(BUIDL_USDC_REDEMPTION),
      'Unexpected redemption contract address'
    );
    assertEq(
      gsmConverter.REDEEMABLE_ASSET(),
      address(BUIDL_TOKEN),
      'Unexpected redeemable asset address'
    );
    assertEq(
      gsmConverter.REDEEMED_ASSET(),
      address(USDC_TOKEN),
      'Unexpected redeemed asset address'
    );
  }

  function testRevertConstructorZeroAddressParams() public {
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GsmConverter(
      address(0),
      address(GHO_BUIDL_GSM),
      address(BUIDL_USDC_REDEMPTION),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );

    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GsmConverter(
      address(this),
      address(0),
      address(BUIDL_USDC_REDEMPTION),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );

    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(0),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );

    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(BUIDL_USDC_REDEMPTION),
      address(0),
      address(USDC_TOKEN)
    );

    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(BUIDL_USDC_REDEMPTION),
      address(BUIDL_TOKEN),
      address(0)
    );
  }

  function testBuyAsset() public {
    uint256 sellFee = GHO_GSM_FIXED_FEE_STRATEGY.getSellFee(DEFAULT_GSM_GHO_AMOUNT);
    uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    (uint256 expectedRedeemedAssetAmount, uint256 expectedGhoSold, , ) = GHO_BUIDL_GSM
      .getGhoAmountForBuyAsset(DEFAULT_GSM_BUIDL_AMOUNT);
    // USDC is redeemed for BUIDL in 1:1 ratio
    uint256 expectedUSDCAmount = DEFAULT_GSM_BUIDL_AMOUNT;

    // Supply BUIDL assets to the BUIDL GSM first
    vm.prank(FAUCET);
    BUIDL_TOKEN.mint(ALICE, DEFAULT_GSM_BUIDL_AMOUNT);
    vm.startPrank(ALICE);
    BUIDL_TOKEN.approve(address(GHO_BUIDL_GSM), DEFAULT_GSM_BUIDL_AMOUNT);
    GHO_BUIDL_GSM.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
    vm.stopPrank();

    // Supply USDC to the Redemption contract
    vm.prank(FAUCET);
    USDC_TOKEN.mint(address(BUIDL_USDC_REDEMPTION), DEFAULT_GSM_BUIDL_AMOUNT);

    // Supply assets to another user
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit BuyAssetThroughRedemption(BOB, BOB, expectedRedeemedAssetAmount, expectedGhoSold);
    (uint256 redeemedUSDCAmount, uint256 ghoSold) = GSM_CONVERTER.buyAsset(
      DEFAULT_GSM_BUIDL_AMOUNT,
      BOB
    );
    vm.stopPrank();

    assertEq(ghoSold, expectedGhoSold, 'Unexpected GHO sold amount');
    assertEq(redeemedUSDCAmount, expectedUSDCAmount, 'Unexpected redeemed buyAsset amount');
    assertEq(USDC_TOKEN.balanceOf(BOB), expectedUSDCAmount, 'Unexpected buyer final USDC balance');
    assertEq(USDC_TOKEN.balanceOf(address(GHO_BUIDL_GSM)), 0, 'Unexpected GSM final USDC balance');
    assertEq(
      USDC_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected converter final USDC balance'
    );
    assertEq(GHO_TOKEN.balanceOf(address(BOB)), 0, 'Unexpected buyer final GHO balance');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      sellFee + buyFee,
      'Unexpected GSM final GHO balance'
    );
    assertEq(GHO_TOKEN.balanceOf(address(GSM_CONVERTER)), 0, 'Unexpected GSM final GHO balance');
    assertEq(BUIDL_TOKEN.balanceOf(BOB), 0, 'Unexpected buyer final BUIDL balance');
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      0,
      'Unexpected GSM final BUIDL balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected converter final BUIDL balance'
    );
  }

  function testBuyAssetSendToOther() public {
    uint256 sellFee = GHO_GSM_FIXED_FEE_STRATEGY.getSellFee(DEFAULT_GSM_GHO_AMOUNT);
    uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    (uint256 expectedRedeemedAssetAmount, uint256 expectedGhoSold, , ) = GHO_BUIDL_GSM
      .getGhoAmountForBuyAsset(DEFAULT_GSM_BUIDL_AMOUNT);
    // USDC is redeemed for BUIDL in 1:1 ratio
    uint256 expectedUSDCAmount = DEFAULT_GSM_BUIDL_AMOUNT;

    // Supply BUIDL assets to the BUIDL GSM first
    vm.prank(FAUCET);
    BUIDL_TOKEN.mint(ALICE, DEFAULT_GSM_BUIDL_AMOUNT);
    vm.startPrank(ALICE);
    BUIDL_TOKEN.approve(address(GHO_BUIDL_GSM), DEFAULT_GSM_BUIDL_AMOUNT);
    GHO_BUIDL_GSM.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
    vm.stopPrank();

    // Supply USDC to the Redemption contract
    vm.prank(FAUCET);
    USDC_TOKEN.mint(address(BUIDL_USDC_REDEMPTION), DEFAULT_GSM_BUIDL_AMOUNT);

    // Supply assets to another user
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit BuyAssetThroughRedemption(BOB, CHARLES, expectedRedeemedAssetAmount, expectedGhoSold);
    (uint256 redeemedUSDCAmount, uint256 ghoSold) = GSM_CONVERTER.buyAsset(
      DEFAULT_GSM_BUIDL_AMOUNT,
      CHARLES
    );
    vm.stopPrank();

    assertEq(ghoSold, expectedGhoSold, 'Unexpected GHO sold amount');
    assertEq(redeemedUSDCAmount, expectedUSDCAmount, 'Unexpected redeemed buyAsset amount');
    assertEq(
      USDC_TOKEN.balanceOf(CHARLES),
      expectedUSDCAmount,
      'Unexpected buyer final USDC balance'
    );
    assertEq(USDC_TOKEN.balanceOf(address(GHO_BUIDL_GSM)), 0, 'Unexpected GSM final USDC balance');
    assertEq(
      USDC_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected converter final USDC balance'
    );
    assertEq(GHO_TOKEN.balanceOf(address(BOB)), 0, 'Unexpected buyer final GHO balance');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      sellFee + buyFee,
      'Unexpected GSM final GHO balance'
    );
    assertEq(GHO_TOKEN.balanceOf(address(GSM_CONVERTER)), 0, 'Unexpected GSM final GHO balance');
    assertEq(BUIDL_TOKEN.balanceOf(BOB), 0, 'Unexpected buyer final BUIDL balance');
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      0,
      'Unexpected GSM final BUIDL balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected converter final BUIDL balance'
    );
  }

  function testRevertBuyAssetZeroAmount() public {
    vm.expectRevert('INVALID_MIN_AMOUNT');
    uint256 invalidAmount = 0;
    GSM_CONVERTER.buyAsset(invalidAmount, ALICE);
  }

  function testRevertBuyAssetNoGHO() public {
    uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);

    // Supply BUIDL assets to the BUIDL GSM first
    vm.prank(FAUCET);
    BUIDL_TOKEN.mint(ALICE, DEFAULT_GSM_BUIDL_AMOUNT);
    vm.startPrank(ALICE);
    BUIDL_TOKEN.approve(address(GHO_BUIDL_GSM), DEFAULT_GSM_BUIDL_AMOUNT);
    GHO_BUIDL_GSM.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
    vm.stopPrank();

    // Supply USDC to the Redemption contract
    vm.prank(FAUCET);
    USDC_TOKEN.mint(address(BUIDL_USDC_REDEMPTION), DEFAULT_GSM_BUIDL_AMOUNT);

    // Supply assets to another user
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.expectRevert(stdError.arithmeticError);
    GSM_CONVERTER.buyAsset(DEFAULT_GSM_BUIDL_AMOUNT, CHARLES);
    vm.stopPrank();
  }

  function testRevertBuyAssetNoAllowance() public {
    // Supply BUIDL assets to the BUIDL GSM first
    vm.prank(FAUCET);
    BUIDL_TOKEN.mint(ALICE, DEFAULT_GSM_BUIDL_AMOUNT);
    vm.startPrank(ALICE);
    BUIDL_TOKEN.approve(address(GHO_BUIDL_GSM), DEFAULT_GSM_BUIDL_AMOUNT);
    GHO_BUIDL_GSM.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
    vm.stopPrank();

    // Supply USDC to the Redemption contract
    vm.prank(FAUCET);
    USDC_TOKEN.mint(address(BUIDL_USDC_REDEMPTION), DEFAULT_GSM_BUIDL_AMOUNT);

    // Supply assets to another user
    vm.startPrank(BOB);
    vm.expectRevert(stdError.arithmeticError);
    GSM_CONVERTER.buyAsset(DEFAULT_GSM_BUIDL_AMOUNT, CHARLES);
    vm.stopPrank();
  }

  function testRescueTokens() public {
    GSM_CONVERTER.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    vm.prank(FAUCET);
    WETH.mint(address(GSM_CONVERTER), 100e18);
    assertEq(WETH.balanceOf(address(GSM_CONVERTER)), 100e18, 'Unexpected GSM WETH before balance');
    assertEq(WETH.balanceOf(ALICE), 0, 'Unexpected target WETH before balance');
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit TokensRescued(address(WETH), ALICE, 100e18);
    GSM_CONVERTER.rescueTokens(address(WETH), ALICE, 100e18);
    assertEq(WETH.balanceOf(address(GSM_CONVERTER)), 0, 'Unexpected GSM WETH after balance');
    assertEq(WETH.balanceOf(ALICE), 100e18, 'Unexpected target WETH after balance');
  }

  function testRevertRescueTokensZeroAmount() public {
    GSM_CONVERTER.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));
    vm.expectRevert('INVALID_AMOUNT');
    GSM_CONVERTER.rescueTokens(address(WETH), ALICE, 0);
  }

  function testRevertRescueTokensInsufficientAmount() public {
    GSM_CONVERTER.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));
    vm.expectRevert();
    GSM_CONVERTER.rescueTokens(address(WETH), ALICE, 1);
  }

  function testRescueGhoTokens() public {
    GSM_CONVERTER.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    ghoFaucet(address(GSM_CONVERTER), 100e18);
    assertEq(
      GHO_TOKEN.balanceOf(address(GSM_CONVERTER)),
      100e18,
      'Unexpected GSM GHO before balance'
    );
    assertEq(GHO_TOKEN.balanceOf(ALICE), 0, 'Unexpected target GHO before balance');
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit TokensRescued(address(GHO_TOKEN), ALICE, 100e18);
    GSM_CONVERTER.rescueTokens(address(GHO_TOKEN), ALICE, 100e18);
    assertEq(GHO_TOKEN.balanceOf(address(GSM_CONVERTER)), 0, 'Unexpected GSM GHO after balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), 100e18, 'Unexpected target GHO after balance');
  }

  function testRescueRedeemedTokens() public {
    GSM_CONVERTER.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    vm.prank(FAUCET);
    USDC_TOKEN.mint(address(GSM_CONVERTER), DEFAULT_GSM_USDC_AMOUNT);

    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected USDC balance before');
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit TokensRescued(address(USDC_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    GSM_CONVERTER.rescueTokens(address(USDC_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    assertEq(USDC_TOKEN.balanceOf(ALICE), DEFAULT_GSM_USDC_AMOUNT, 'Unexpected USDC balance after');
  }

  function testRescueRedeemableTokens() public {
    GSM_CONVERTER.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    vm.prank(FAUCET);
    BUIDL_TOKEN.mint(address(GSM_CONVERTER), DEFAULT_GSM_USDC_AMOUNT);

    assertEq(BUIDL_TOKEN.balanceOf(ALICE), 0, 'Unexpected BUIDL balance before');
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit TokensRescued(address(BUIDL_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    GSM_CONVERTER.rescueTokens(address(BUIDL_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    assertEq(
      BUIDL_TOKEN.balanceOf(ALICE),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected BUIDL balance after'
    );
  }
}

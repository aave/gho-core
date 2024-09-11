// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsmConverter is TestGhoBase {
  // using PercentageMath for uint256;
  // using PercentageMath for uint128;

  address public gsmConverterSignerAddr;
  uint256 public gsmConverterSignerKey;

  function setUp() public {}

  function testConstructor() public {
    GsmConverter gsmConverter = new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(BUIDL_USDC_REDEMPTION),
      address(BUIDL_USDC_ISSUANCE),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );
    assertEq(gsmConverter.owner(), address(this), 'Unexpected default admin address');
    assertEq(gsmConverter.GSM(), address(GHO_BUIDL_GSM), 'Unexpected GSM address');
    assertEq(
      gsmConverter.REDEMPTION_CONTRACT(),
      address(BUIDL_USDC_REDEMPTION),
      'Unexpected redemption contract address'
    );
    assertEq(
      gsmConverter.ISSUANCE_RECEIVER_CONTRACT(),
      address(BUIDL_USDC_ISSUANCE),
      'Unexpected issuance receiver contract address'
    );
    assertEq(gsmConverter.ISSUED_ASSET(), address(BUIDL_TOKEN), 'Unexpected issued asset address');
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
      address(BUIDL_USDC_ISSUANCE),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );

    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GsmConverter(
      address(this),
      address(0),
      address(BUIDL_USDC_REDEMPTION),
      address(BUIDL_USDC_ISSUANCE),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );

    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(0),
      address(BUIDL_USDC_ISSUANCE),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );

    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(BUIDL_USDC_REDEMPTION),
      address(0),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );

    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(BUIDL_USDC_REDEMPTION),
      address(BUIDL_USDC_ISSUANCE),
      address(0),
      address(USDC_TOKEN)
    );

    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(BUIDL_USDC_REDEMPTION),
      address(BUIDL_USDC_ISSUANCE),
      address(BUIDL_TOKEN),
      address(0)
    );
  }

  function testSellAsset() public {
    uint256 sellFee = GHO_GSM_FIXED_FEE_STRATEGY.getSellFee(DEFAULT_GSM_GHO_AMOUNT);
    (uint256 expectedIssuedAssetAmount, uint256 expectedGhoBought, , ) = GHO_BUIDL_GSM
      .getGhoAmountForSellAsset(DEFAULT_GSM_BUIDL_AMOUNT);

    vm.startPrank(FAUCET);
    // Supply USDC to buyer
    USDC_TOKEN.mint(ALICE, expectedIssuedAssetAmount);
    // Supply BUIDL to issuance contract
    BUIDL_TOKEN.mint(address(BUIDL_USDC_ISSUANCE), expectedIssuedAssetAmount);
    vm.stopPrank();

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GSM_CONVERTER), expectedIssuedAssetAmount);

    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit SellAssetThroughIssuance(ALICE, ALICE, expectedIssuedAssetAmount, expectedGhoBought);
    (uint256 assetAmount, uint256 ghoBought) = GSM_CONVERTER.sellAsset(
      DEFAULT_GSM_BUIDL_AMOUNT,
      ALICE
    );
    vm.stopPrank();

    assertEq(ghoBought, expectedGhoBought, 'Unexpected GHO bought amount');
    assertEq(assetAmount, expectedIssuedAssetAmount, 'Unexpected asset amount sold');
    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected seller final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoBought, 'Unexpected seller final GHO balance');
    assertEq(
      BUIDL_TOKEN.balanceOf(ALICE),
      0,
      'Unexpected seller final BUIDL (issued asset) balance'
    );
    assertEq(USDC_TOKEN.balanceOf(address(GHO_BUIDL_GSM)), 0, 'Unexpected GSM final USDC balance');
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      assetAmount,
      'Unexpected GSM final BUIDL balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      sellFee,
      'Unexpected GSM final GHO balance'
    );
    assertEq(
      USDC_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final USDC balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final BUIDL balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(BUIDL_USDC_ISSUANCE)),
      0,
      'Unexpected Issuance final BUIDL balance'
    );
    assertEq(
      USDC_TOKEN.balanceOf(address(BUIDL_USDC_ISSUANCE)),
      expectedIssuedAssetAmount,
      'Unexpected Issuance final USDC balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(BUIDL_USDC_ISSUANCE)),
      0,
      'Unexpected Issuance final GHO balance'
    );
  }

  function testSellAssetSendToOther() public {
    uint256 sellFee = GHO_GSM_FIXED_FEE_STRATEGY.getSellFee(DEFAULT_GSM_GHO_AMOUNT);
    (uint256 expectedIssuedAssetAmount, uint256 expectedGhoBought, , ) = GHO_BUIDL_GSM
      .getGhoAmountForSellAsset(DEFAULT_GSM_BUIDL_AMOUNT);

    vm.startPrank(FAUCET);
    // Supply USDC to buyer
    USDC_TOKEN.mint(ALICE, expectedIssuedAssetAmount);
    // Supply BUIDL to issuance contract
    BUIDL_TOKEN.mint(address(BUIDL_USDC_ISSUANCE), expectedIssuedAssetAmount);
    vm.stopPrank();

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GSM_CONVERTER), expectedIssuedAssetAmount);

    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit SellAssetThroughIssuance(ALICE, BOB, expectedIssuedAssetAmount, expectedGhoBought);
    (uint256 assetAmount, uint256 ghoBought) = GSM_CONVERTER.sellAsset(
      DEFAULT_GSM_BUIDL_AMOUNT,
      BOB
    );
    vm.stopPrank();

    assertEq(ghoBought, expectedGhoBought, 'Unexpected GHO bought amount');
    assertEq(assetAmount, expectedIssuedAssetAmount, 'Unexpected asset amount sold');
    assertEq(USDC_TOKEN.balanceOf(BOB), 0, 'Unexpected receiver final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(BOB), ghoBought, 'Unexpected receiver final GHO balance');
    assertEq(
      BUIDL_TOKEN.balanceOf(BOB),
      0,
      'Unexpected receiver final BUIDL (issued asset) balance'
    );
    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected seller final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), 0, 'Unexpected seller final GHO balance');
    assertEq(
      BUIDL_TOKEN.balanceOf(ALICE),
      0,
      'Unexpected seller final BUIDL (issued asset) balance'
    );
    assertEq(USDC_TOKEN.balanceOf(address(GHO_BUIDL_GSM)), 0, 'Unexpected GSM final USDC balance');
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      assetAmount,
      'Unexpected GSM final BUIDL balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      sellFee,
      'Unexpected GSM final GHO balance'
    );
    assertEq(
      USDC_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final USDC balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final BUIDL balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(BUIDL_USDC_ISSUANCE)),
      0,
      'Unexpected Issuance final BUIDL balance'
    );
    assertEq(
      USDC_TOKEN.balanceOf(address(BUIDL_USDC_ISSUANCE)),
      expectedIssuedAssetAmount,
      'Unexpected Issuance final USDC balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(BUIDL_USDC_ISSUANCE)),
      0,
      'Unexpected Issuance final GHO balance'
    );
  }

  function testRevertSellAssetZeroAmount() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_MAX_AMOUNT');
    GSM_CONVERTER.sellAsset(0, ALICE);
  }

  function testRevertSellAssetNoAsset() public {
    vm.startPrank(ALICE);
    BUIDL_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_BUIDL_AMOUNT);
    vm.expectRevert('ERC20: transfer amount exceeds balance');
    GSM_CONVERTER.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
    vm.stopPrank();
  }

  function testRevertSellAssetNoAllowanceRedeemedAsset() public {
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_BUIDL_AMOUNT);

    vm.prank(ALICE);
    vm.expectRevert('ERC20: transfer amount exceeds allowance');
    GSM_CONVERTER.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
  }

  function testRevertSellAssetInvalidIssuance() public {
    GsmConverter gsmConverter = new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(BUIDL_USDC_REDEMPTION),
      address(BUIDL_USDC_ISSUANCE_FAILED),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );

    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_BUIDL_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(gsmConverter), DEFAULT_GSM_BUIDL_AMOUNT);
    vm.expectRevert('INVALID_ISSUANCE');
    gsmConverter.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
  }

  function testRevertSellAssetInvalidRemainingGhoBalance() public {
    _upgradeToGsmFailedSellAssetRemainingGhoBalance();

    vm.startPrank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_BUIDL_AMOUNT);
    BUIDL_TOKEN.mint(address(BUIDL_USDC_ISSUANCE), DEFAULT_GSM_BUIDL_AMOUNT);
    vm.stopPrank();

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_BUIDL_AMOUNT);
    vm.expectRevert('INVALID_REMAINING_GHO_BALANCE');
    GSM_CONVERTER.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
  }

  function testRevertSellAssetInvalidRedeemedAssetBalance() public {
    GsmConverter gsmConverter = new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(BUIDL_USDC_REDEMPTION),
      address(BUIDL_USDC_ISSUANCE_FAILED_INVALID_USDC),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );

    vm.startPrank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_BUIDL_AMOUNT);
    BUIDL_TOKEN.mint(address(BUIDL_USDC_ISSUANCE_FAILED_INVALID_USDC), DEFAULT_GSM_BUIDL_AMOUNT);
    vm.stopPrank();

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(gsmConverter), DEFAULT_GSM_BUIDL_AMOUNT);
    vm.expectRevert('INVALID_REMAINING_REDEEMED_ASSET_BALANCE');
    gsmConverter.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
  }

  function testSellAssetWithSig() public {
    (gsmConverterSignerAddr, gsmConverterSignerKey) = makeAddrAndKey('randomString');

    uint256 deadline = block.timestamp + 1 hours;
    uint256 sellFee = GHO_GSM_FIXED_FEE_STRATEGY.getSellFee(DEFAULT_GSM_GHO_AMOUNT);
    (uint256 expectedIssuedAssetAmount, uint256 expectedGhoBought, , ) = GHO_BUIDL_GSM
      .getGhoAmountForSellAsset(DEFAULT_GSM_BUIDL_AMOUNT);

    vm.startPrank(FAUCET);
    // Supply USDC to buyer
    USDC_TOKEN.mint(gsmConverterSignerAddr, expectedIssuedAssetAmount);
    // Supply BUIDL to issuance contract
    BUIDL_TOKEN.mint(address(BUIDL_USDC_ISSUANCE), expectedIssuedAssetAmount);
    vm.stopPrank();

    vm.prank(gsmConverterSignerAddr);
    USDC_TOKEN.approve(address(GSM_CONVERTER), expectedIssuedAssetAmount);

    assertEq(
      GSM_CONVERTER.nonces(gsmConverterSignerAddr),
      0,
      'Unexpected before gsmConverterSignerAddr nonce'
    );

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GSM_CONVERTER.DOMAIN_SEPARATOR(),
        GSM_CONVERTER_SELL_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(
          gsmConverterSignerAddr,
          DEFAULT_GSM_BUIDL_AMOUNT,
          gsmConverterSignerAddr,
          GSM_CONVERTER.nonces(gsmConverterSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmConverterSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmConverterSignerAddr != ALICE, 'Signer is the same as Bob');

    vm.prank(ALICE);
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit SellAssetThroughIssuance(
      gsmConverterSignerAddr,
      gsmConverterSignerAddr,
      expectedIssuedAssetAmount,
      expectedGhoBought
    );
    (uint256 assetAmount, uint256 ghoBought) = GSM_CONVERTER.sellAssetWithSig(
      gsmConverterSignerAddr,
      DEFAULT_GSM_BUIDL_AMOUNT,
      gsmConverterSignerAddr,
      deadline,
      signature
    );
    vm.stopPrank();

    assertEq(ghoBought, expectedGhoBought, 'Unexpected GHO bought amount');
    assertEq(assetAmount, expectedIssuedAssetAmount, 'Unexpected asset amount sold');
    assertEq(
      USDC_TOKEN.balanceOf(gsmConverterSignerAddr),
      0,
      'Unexpected signer final USDC balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(gsmConverterSignerAddr),
      ghoBought,
      'Unexpected signer final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(gsmConverterSignerAddr),
      0,
      'Unexpected signer final BUIDL (issued asset) balance'
    );
    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected seller final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), 0, 'Unexpected seller final GHO balance');
    assertEq(
      BUIDL_TOKEN.balanceOf(ALICE),
      0,
      'Unexpected seller final BUIDL (issued asset) balance'
    );
    assertEq(USDC_TOKEN.balanceOf(address(GHO_BUIDL_GSM)), 0, 'Unexpected GSM final USDC balance');
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      assetAmount,
      'Unexpected GSM final BUIDL balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      sellFee,
      'Unexpected GSM final GHO balance'
    );
    assertEq(
      USDC_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final USDC balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final BUIDL balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(BUIDL_USDC_ISSUANCE)),
      0,
      'Unexpected Issuance final BUIDL balance'
    );
    assertEq(
      USDC_TOKEN.balanceOf(address(BUIDL_USDC_ISSUANCE)),
      expectedIssuedAssetAmount,
      'Unexpected Issuance final USDC balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(BUIDL_USDC_ISSUANCE)),
      0,
      'Unexpected Issuance final GHO balance'
    );
  }

  function testSellAssetWithSigExactDeadline() public {
    (gsmConverterSignerAddr, gsmConverterSignerKey) = makeAddrAndKey('randomString');

    uint256 deadline = block.timestamp;
    uint256 sellFee = GHO_GSM_FIXED_FEE_STRATEGY.getSellFee(DEFAULT_GSM_GHO_AMOUNT);
    (uint256 expectedIssuedAssetAmount, uint256 expectedGhoBought, , ) = GHO_BUIDL_GSM
      .getGhoAmountForSellAsset(DEFAULT_GSM_BUIDL_AMOUNT);

    vm.startPrank(FAUCET);
    // Supply USDC to buyer
    USDC_TOKEN.mint(gsmConverterSignerAddr, expectedIssuedAssetAmount);
    // Supply BUIDL to issuance contract
    BUIDL_TOKEN.mint(address(BUIDL_USDC_ISSUANCE), expectedIssuedAssetAmount);
    vm.stopPrank();

    vm.prank(gsmConverterSignerAddr);
    USDC_TOKEN.approve(address(GSM_CONVERTER), expectedIssuedAssetAmount);

    assertEq(
      GSM_CONVERTER.nonces(gsmConverterSignerAddr),
      0,
      'Unexpected before gsmConverterSignerAddr nonce'
    );

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GSM_CONVERTER.DOMAIN_SEPARATOR(),
        GSM_CONVERTER_SELL_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(
          gsmConverterSignerAddr,
          DEFAULT_GSM_BUIDL_AMOUNT,
          gsmConverterSignerAddr,
          GSM_CONVERTER.nonces(gsmConverterSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmConverterSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmConverterSignerAddr != ALICE, 'Signer is the same as Bob');

    vm.prank(ALICE);
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit SellAssetThroughIssuance(
      gsmConverterSignerAddr,
      gsmConverterSignerAddr,
      expectedIssuedAssetAmount,
      expectedGhoBought
    );
    (uint256 assetAmount, uint256 ghoBought) = GSM_CONVERTER.sellAssetWithSig(
      gsmConverterSignerAddr,
      DEFAULT_GSM_BUIDL_AMOUNT,
      gsmConverterSignerAddr,
      deadline,
      signature
    );
    vm.stopPrank();

    assertEq(ghoBought, expectedGhoBought, 'Unexpected GHO bought amount');
    assertEq(assetAmount, expectedIssuedAssetAmount, 'Unexpected asset amount sold');
    assertEq(
      USDC_TOKEN.balanceOf(gsmConverterSignerAddr),
      0,
      'Unexpected signer final USDC balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(gsmConverterSignerAddr),
      ghoBought,
      'Unexpected signer final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(gsmConverterSignerAddr),
      0,
      'Unexpected signer final BUIDL (issued asset) balance'
    );
    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected seller final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), 0, 'Unexpected seller final GHO balance');
    assertEq(
      BUIDL_TOKEN.balanceOf(ALICE),
      0,
      'Unexpected seller final BUIDL (issued asset) balance'
    );
    assertEq(USDC_TOKEN.balanceOf(address(GHO_BUIDL_GSM)), 0, 'Unexpected GSM final USDC balance');
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      assetAmount,
      'Unexpected GSM final BUIDL balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      sellFee,
      'Unexpected GSM final GHO balance'
    );
    assertEq(
      USDC_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final USDC balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final BUIDL balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(BUIDL_USDC_ISSUANCE)),
      0,
      'Unexpected Issuance final BUIDL balance'
    );
    assertEq(
      USDC_TOKEN.balanceOf(address(BUIDL_USDC_ISSUANCE)),
      expectedIssuedAssetAmount,
      'Unexpected Issuance final USDC balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(BUIDL_USDC_ISSUANCE)),
      0,
      'Unexpected Issuance final GHO balance'
    );
  }

  function testRevertSellAssetWithSigExpiredSignature() public {
    (gsmConverterSignerAddr, gsmConverterSignerKey) = makeAddrAndKey('randomString');

    uint256 deadline = block.timestamp - 1;
    (uint256 expectedIssuedAssetAmount, , , ) = GHO_BUIDL_GSM.getGhoAmountForSellAsset(
      DEFAULT_GSM_BUIDL_AMOUNT
    );

    vm.startPrank(FAUCET);
    // Supply USDC to buyer
    USDC_TOKEN.mint(gsmConverterSignerAddr, expectedIssuedAssetAmount);
    // Supply BUIDL to issuance contract
    BUIDL_TOKEN.mint(address(BUIDL_USDC_ISSUANCE), expectedIssuedAssetAmount);
    vm.stopPrank();

    vm.prank(gsmConverterSignerAddr);
    USDC_TOKEN.approve(address(GSM_CONVERTER), expectedIssuedAssetAmount);

    assertEq(
      GSM_CONVERTER.nonces(gsmConverterSignerAddr),
      0,
      'Unexpected before gsmConverterSignerAddr nonce'
    );

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GSM_CONVERTER.DOMAIN_SEPARATOR(),
        GSM_CONVERTER_SELL_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(
          gsmConverterSignerAddr,
          DEFAULT_GSM_BUIDL_AMOUNT,
          gsmConverterSignerAddr,
          GSM_CONVERTER.nonces(gsmConverterSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmConverterSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmConverterSignerAddr != ALICE, 'Signer is the same as Bob');

    vm.prank(ALICE);
    vm.expectRevert('SIGNATURE_DEADLINE_EXPIRED');
    GSM_CONVERTER.sellAssetWithSig(
      gsmConverterSignerAddr,
      DEFAULT_GSM_BUIDL_AMOUNT,
      gsmConverterSignerAddr,
      deadline,
      signature
    );
    vm.stopPrank();
  }

  function testRevertSellAssetWithSigInvalidSignature() public {
    (gsmConverterSignerAddr, gsmConverterSignerKey) = makeAddrAndKey('randomString');

    uint256 deadline = block.timestamp + 10;
    (uint256 expectedIssuedAssetAmount, , , ) = GHO_BUIDL_GSM.getGhoAmountForSellAsset(
      DEFAULT_GSM_BUIDL_AMOUNT
    );

    vm.startPrank(FAUCET);
    // Supply USDC to buyer
    USDC_TOKEN.mint(gsmConverterSignerAddr, expectedIssuedAssetAmount);
    // Supply BUIDL to issuance contract
    BUIDL_TOKEN.mint(address(BUIDL_USDC_ISSUANCE), expectedIssuedAssetAmount);
    vm.stopPrank();

    vm.prank(gsmConverterSignerAddr);
    USDC_TOKEN.approve(address(GSM_CONVERTER), expectedIssuedAssetAmount);

    assertEq(
      GSM_CONVERTER.nonces(gsmConverterSignerAddr),
      0,
      'Unexpected before gsmConverterSignerAddr nonce'
    );

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GSM_CONVERTER.DOMAIN_SEPARATOR(),
        GSM_CONVERTER_SELL_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(
          gsmConverterSignerAddr,
          DEFAULT_GSM_BUIDL_AMOUNT,
          gsmConverterSignerAddr,
          GSM_CONVERTER.nonces(gsmConverterSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmConverterSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmConverterSignerAddr != ALICE, 'Signer is the same as Bob');

    vm.prank(ALICE);
    vm.expectRevert('SIGNATURE_INVALID');
    GSM_CONVERTER.sellAssetWithSig(ALICE, DEFAULT_GSM_BUIDL_AMOUNT, ALICE, deadline, signature);
    vm.stopPrank();
  }

  function testRevertSellAssetWithSigInvalidAmount() public {
    (gsmConverterSignerAddr, gsmConverterSignerKey) = makeAddrAndKey('randomString');

    uint256 deadline = block.timestamp + 10;
    (uint256 expectedIssuedAssetAmount, , , ) = GHO_BUIDL_GSM.getGhoAmountForSellAsset(
      DEFAULT_GSM_BUIDL_AMOUNT
    );

    vm.startPrank(FAUCET);
    // Supply USDC to buyer
    USDC_TOKEN.mint(gsmConverterSignerAddr, expectedIssuedAssetAmount);
    // Supply BUIDL to issuance contract
    BUIDL_TOKEN.mint(address(BUIDL_USDC_ISSUANCE), expectedIssuedAssetAmount);
    vm.stopPrank();

    vm.prank(gsmConverterSignerAddr);
    USDC_TOKEN.approve(address(GSM_CONVERTER), expectedIssuedAssetAmount);

    assertEq(
      GSM_CONVERTER.nonces(gsmConverterSignerAddr),
      0,
      'Unexpected before gsmConverterSignerAddr nonce'
    );

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GSM_CONVERTER.DOMAIN_SEPARATOR(),
        GSM_CONVERTER_SELL_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(
          gsmConverterSignerAddr,
          DEFAULT_GSM_BUIDL_AMOUNT - 1,
          gsmConverterSignerAddr,
          GSM_CONVERTER.nonces(gsmConverterSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmConverterSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmConverterSignerAddr != ALICE, 'Signer is the same as Bob');

    vm.prank(ALICE);
    vm.expectRevert('SIGNATURE_INVALID');
    GSM_CONVERTER.sellAssetWithSig(
      gsmConverterSignerAddr,
      DEFAULT_GSM_BUIDL_AMOUNT,
      gsmConverterSignerAddr,
      deadline,
      signature
    );
    vm.stopPrank();
  }

  // TODO: test for buyAsset, check assertions on every balance
  // TODO: test for buyAsset/withsig - when tokens are directly sent to the contract

  function testBuyAsset() public {
    uint256 sellFee = GHO_GSM_FIXED_FEE_STRATEGY.getSellFee(DEFAULT_GSM_GHO_AMOUNT);
    uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    (uint256 expectedRedeemedAssetAmount, uint256 expectedGhoSold, , ) = GHO_BUIDL_GSM
      .getGhoAmountForBuyAsset(DEFAULT_GSM_BUIDL_AMOUNT);

    // Supply BUIDL assets to the BUIDL GSM first
    vm.prank(FAUCET);
    BUIDL_TOKEN.mint(ALICE, expectedRedeemedAssetAmount);
    vm.startPrank(ALICE);
    BUIDL_TOKEN.approve(address(GHO_BUIDL_GSM), expectedRedeemedAssetAmount);
    GHO_BUIDL_GSM.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
    vm.stopPrank();

    // Supply USDC to the Redemption contract
    vm.prank(FAUCET);
    USDC_TOKEN.mint(address(BUIDL_USDC_REDEMPTION), expectedRedeemedAssetAmount);

    // Supply assets to another user
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_GHO_AMOUNT + buyFee);

    // Buy assets via Redemption of USDC
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit BuyAssetThroughRedemption(BOB, BOB, expectedRedeemedAssetAmount, expectedGhoSold);
    (uint256 redeemedUSDCAmount, uint256 ghoSold) = GSM_CONVERTER.buyAsset(
      DEFAULT_GSM_BUIDL_AMOUNT,
      BOB
    );
    vm.stopPrank();

    assertEq(ghoSold, expectedGhoSold, 'Unexpected GHO sold amount');
    assertEq(
      redeemedUSDCAmount,
      expectedRedeemedAssetAmount,
      'Unexpected redeemed buyAsset amount'
    );
    assertEq(
      USDC_TOKEN.balanceOf(BOB),
      expectedRedeemedAssetAmount,
      'Unexpected buyer final USDC balance'
    );
    assertEq(GHO_TOKEN.balanceOf(address(BOB)), 0, 'Unexpected buyer final GHO balance');
    assertEq(BUIDL_TOKEN.balanceOf(BOB), 0, 'Unexpected buyer final BUIDL balance');
    assertEq(USDC_TOKEN.balanceOf(address(GHO_BUIDL_GSM)), 0, 'Unexpected GSM final USDC balance');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      sellFee + buyFee,
      'Unexpected GSM final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      0,
      'Unexpected GSM final BUIDL balance'
    );
    assertEq(
      USDC_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected converter final USDC balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final BUIDL balance'
    );
  }

  function testBuyAssetSendToOther() public {
    uint256 sellFee = GHO_GSM_FIXED_FEE_STRATEGY.getSellFee(DEFAULT_GSM_GHO_AMOUNT);
    uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    (uint256 expectedRedeemedAssetAmount, uint256 expectedGhoSold, , ) = GHO_BUIDL_GSM
      .getGhoAmountForBuyAsset(DEFAULT_GSM_BUIDL_AMOUNT);

    // Supply BUIDL assets to the BUIDL GSM first
    vm.prank(FAUCET);
    BUIDL_TOKEN.mint(ALICE, expectedRedeemedAssetAmount);
    vm.startPrank(ALICE);
    BUIDL_TOKEN.approve(address(GHO_BUIDL_GSM), expectedRedeemedAssetAmount);
    GHO_BUIDL_GSM.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
    vm.stopPrank();

    // Supply USDC to the Redemption contract
    vm.prank(FAUCET);
    USDC_TOKEN.mint(address(BUIDL_USDC_REDEMPTION), expectedRedeemedAssetAmount);

    // Supply assets to another user
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_GHO_AMOUNT + buyFee);

    // Buy assets via Redemption of USDC
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit BuyAssetThroughRedemption(BOB, CHARLES, expectedRedeemedAssetAmount, expectedGhoSold);
    (uint256 redeemedUSDCAmount, uint256 ghoSold) = GSM_CONVERTER.buyAsset(
      DEFAULT_GSM_BUIDL_AMOUNT,
      CHARLES
    );
    vm.stopPrank();

    assertEq(ghoSold, expectedGhoSold, 'Unexpected GHO sold amount');
    assertEq(
      redeemedUSDCAmount,
      expectedRedeemedAssetAmount,
      'Unexpected redeemed buyAsset amount'
    );
    assertEq(
      USDC_TOKEN.balanceOf(CHARLES),
      expectedRedeemedAssetAmount,
      'Unexpected buyer final USDC balance'
    );
    assertEq(GHO_TOKEN.balanceOf(address(CHARLES)), 0, 'Unexpected receiver final GHO balance');
    assertEq(BUIDL_TOKEN.balanceOf(CHARLES), 0, 'Unexpected receiver final BUIDL balance');
    assertEq(USDC_TOKEN.balanceOf(BOB), 0, 'Unexpected receiver final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(address(BOB)), 0, 'Unexpected buyer final GHO balance');
    assertEq(BUIDL_TOKEN.balanceOf(BOB), 0, 'Unexpected buyer final BUIDL balance');
    assertEq(USDC_TOKEN.balanceOf(address(GHO_BUIDL_GSM)), 0, 'Unexpected GSM final USDC balance');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      sellFee + buyFee,
      'Unexpected GSM final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      0,
      'Unexpected GSM final BUIDL balance'
    );
    assertEq(
      USDC_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected converter final USDC balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final BUIDL balance'
    );
  }

  function testBuyAssetWithDonatedTokens() public {
    uint256 sellFee = GHO_GSM_FIXED_FEE_STRATEGY.getSellFee(DEFAULT_GSM_GHO_AMOUNT);
    uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    (uint256 expectedRedeemedAssetAmount, uint256 expectedGhoSold, , ) = GHO_BUIDL_GSM
      .getGhoAmountForBuyAsset(DEFAULT_GSM_BUIDL_AMOUNT);
    uint256 donatedAmount = 1e6;

    // Supply BUIDL assets to the BUIDL GSM first
    vm.startPrank(FAUCET);
    BUIDL_TOKEN.mint(ALICE, expectedRedeemedAssetAmount);
    // donate tokens to the converter
    BUIDL_TOKEN.mint(address(GSM_CONVERTER), donatedAmount);
    USDC_TOKEN.mint(address(GSM_CONVERTER), donatedAmount);
    vm.stopPrank();
    ghoFaucet(address(GSM_CONVERTER), donatedAmount);

    // sellAsset to seed GSM
    vm.startPrank(ALICE);
    BUIDL_TOKEN.approve(address(GHO_BUIDL_GSM), expectedRedeemedAssetAmount);
    GHO_BUIDL_GSM.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
    vm.stopPrank();

    // Supply USDC to the Redemption contract
    vm.prank(FAUCET);
    USDC_TOKEN.mint(address(BUIDL_USDC_REDEMPTION), expectedRedeemedAssetAmount);

    // Supply assets to another user
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_GHO_AMOUNT + buyFee);

    // Buy assets via Redemption of USDC
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit BuyAssetThroughRedemption(BOB, BOB, expectedRedeemedAssetAmount, expectedGhoSold);
    (uint256 redeemedUSDCAmount, uint256 ghoSold) = GSM_CONVERTER.buyAsset(
      DEFAULT_GSM_BUIDL_AMOUNT,
      BOB
    );
    vm.stopPrank();

    assertEq(ghoSold, expectedGhoSold, 'Unexpected GHO sold amount');
    assertEq(
      redeemedUSDCAmount,
      expectedRedeemedAssetAmount,
      'Unexpected redeemed buyAsset amount'
    );
    assertEq(
      USDC_TOKEN.balanceOf(BOB),
      expectedRedeemedAssetAmount,
      'Unexpected buyer final USDC balance'
    );
    assertEq(GHO_TOKEN.balanceOf(address(BOB)), 0, 'Unexpected buyer final GHO balance');
    assertEq(BUIDL_TOKEN.balanceOf(BOB), 0, 'Unexpected buyer final BUIDL balance');
    assertEq(USDC_TOKEN.balanceOf(address(GHO_BUIDL_GSM)), 0, 'Unexpected GSM final USDC balance');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      sellFee + buyFee,
      'Unexpected GSM final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      0,
      'Unexpected GSM final BUIDL balance'
    );
    assertEq(
      USDC_TOKEN.balanceOf(address(GSM_CONVERTER)),
      donatedAmount,
      'Unexpected GSM_CONVERTER final USDC balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GSM_CONVERTER)),
      donatedAmount,
      'Unexpected GSM_CONVERTER final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GSM_CONVERTER)),
      donatedAmount,
      'Unexpected GSM_CONVERTER final BUIDL balance'
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

    // Buy assets via Redemption of USDC
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

    // Buy assets via Redemption of USDC
    vm.startPrank(BOB);
    vm.expectRevert(stdError.arithmeticError);
    GSM_CONVERTER.buyAsset(DEFAULT_GSM_BUIDL_AMOUNT, CHARLES);
    vm.stopPrank();
  }

  function testRevertBuyAssetInvalidGhoSold() public {
    _upgradeToGsmFailedBuyAssetGhoAmount();

    uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    (, uint256 expectedGhoSold, , ) = GHO_BUIDL_GSM.getGhoAmountForBuyAsset(
      DEFAULT_GSM_BUIDL_AMOUNT
    );

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
    ghoFaucet(BOB, expectedGhoSold + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GSM_CONVERTER), expectedGhoSold + buyFee);

    // Buy assets via Redemption of USDC
    vm.expectRevert('INVALID_GHO_SOLD');
    GSM_CONVERTER.buyAsset(DEFAULT_GSM_BUIDL_AMOUNT, BOB);
    vm.stopPrank();
  }

  function testRevertBuyAssetInvalidRemainingGhoBalance() public {
    _upgradeToGsmFailedBuyAssetRemainingGhoBalance();

    uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    (, uint256 expectedGhoSold, , ) = GHO_BUIDL_GSM.getGhoAmountForBuyAsset(
      DEFAULT_GSM_BUIDL_AMOUNT
    );

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
    ghoFaucet(BOB, expectedGhoSold + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GSM_CONVERTER), expectedGhoSold + buyFee);

    // Buy assets via Redemption of USDC
    vm.expectRevert('INVALID_REMAINING_GHO_BALANCE');
    GSM_CONVERTER.buyAsset(DEFAULT_GSM_BUIDL_AMOUNT, BOB);
    vm.stopPrank();
  }

  function testRevertBuyAssetInvalidRemainingIssuedAssetBalance() public {
    GsmConverter gsmConverter = new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(BUIDL_USDC_REDEMPTION_FAILED_ISSUED_ASSET_AMOUNT),
      address(BUIDL_USDC_ISSUANCE),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );

    uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    (, uint256 expectedGhoSold, , ) = GHO_BUIDL_GSM.getGhoAmountForBuyAsset(
      DEFAULT_GSM_BUIDL_AMOUNT
    );

    // Supply BUIDL assets to the BUIDL GSM first
    vm.prank(FAUCET);
    BUIDL_TOKEN.mint(ALICE, DEFAULT_GSM_BUIDL_AMOUNT);
    vm.startPrank(ALICE);
    BUIDL_TOKEN.approve(address(GHO_BUIDL_GSM), DEFAULT_GSM_BUIDL_AMOUNT);
    GHO_BUIDL_GSM.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
    vm.stopPrank();

    // Supply USDC to the Redemption contract
    vm.prank(FAUCET);
    USDC_TOKEN.mint(
      address(BUIDL_USDC_REDEMPTION_FAILED_ISSUED_ASSET_AMOUNT),
      DEFAULT_GSM_BUIDL_AMOUNT
    );

    // Supply assets to another user
    ghoFaucet(BOB, expectedGhoSold + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(gsmConverter), expectedGhoSold + buyFee);

    // Buy assets via Redemption of USDC
    vm.expectRevert('INVALID_REMAINING_ISSUED_ASSET_BALANCE');
    gsmConverter.buyAsset(DEFAULT_GSM_BUIDL_AMOUNT, BOB);
    vm.stopPrank();
  }

  function testRevertBuyAssetInvalidRedemption() public {
    GsmConverter gsmConverter = new GsmConverter(
      address(this),
      address(GHO_BUIDL_GSM),
      address(BUIDL_USDC_REDEMPTION_FAILED),
      address(BUIDL_USDC_ISSUANCE),
      address(BUIDL_TOKEN),
      address(USDC_TOKEN)
    );

    uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    (, uint256 expectedGhoSold, , ) = GHO_BUIDL_GSM.getGhoAmountForBuyAsset(
      DEFAULT_GSM_BUIDL_AMOUNT
    );

    // Supply BUIDL assets to the BUIDL GSM first
    vm.prank(FAUCET);
    BUIDL_TOKEN.mint(ALICE, DEFAULT_GSM_BUIDL_AMOUNT);
    vm.startPrank(ALICE);
    BUIDL_TOKEN.approve(address(GHO_BUIDL_GSM), DEFAULT_GSM_BUIDL_AMOUNT);
    GHO_BUIDL_GSM.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
    vm.stopPrank();

    // Supply USDC to the Redemption contract
    vm.prank(FAUCET);
    uint256 bufferForAdditionalTransfer = 1000;
    USDC_TOKEN.mint(
      address(BUIDL_USDC_REDEMPTION_FAILED),
      DEFAULT_GSM_BUIDL_AMOUNT + bufferForAdditionalTransfer
    );

    // Supply assets to another user
    ghoFaucet(BOB, expectedGhoSold + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(gsmConverter), expectedGhoSold + buyFee);

    // Invalid redemption of USDC
    vm.expectRevert('INVALID_REDEMPTION');
    gsmConverter.buyAsset(DEFAULT_GSM_BUIDL_AMOUNT, BOB);
    vm.stopPrank();
  }

  /// TODO: @dev Assuming an attacker donates BUIDL token to the converter
  // function testRevertBuyAssetInvalidRedemptionNonZeroBalance() public {
  //   GsmConverter gsmConverter = new GsmConverter(
  //     address(this),
  //     address(GHO_BUIDL_GSM),
  //     address(BUIDL_USDC_REDEMPTION_FAILED),
  //     address(BUIDL_USDC_ISSUANCE),
  //     address(BUIDL_TOKEN),
  //     address(USDC_TOKEN)
  //   );

  //   uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
  //   (, uint256 expectedGhoSold, , ) = GHO_BUIDL_GSM.getGhoAmountForBuyAsset(
  //     DEFAULT_GSM_BUIDL_AMOUNT
  //   );

  //   // Supply BUIDL assets to the BUIDL GSM first
  //   vm.prank(FAUCET);
  //   BUIDL_TOKEN.mint(ALICE, DEFAULT_GSM_BUIDL_AMOUNT);
  //   vm.startPrank(ALICE);
  //   BUIDL_TOKEN.approve(address(GHO_BUIDL_GSM), DEFAULT_GSM_BUIDL_AMOUNT);
  //   GHO_BUIDL_GSM.sellAsset(DEFAULT_GSM_BUIDL_AMOUNT, ALICE);
  //   vm.stopPrank();

  //   // Supply USDC to the Redemption contract
  //   vm.prank(FAUCET);
  //   uint256 bufferForAdditionalTransfer = 1000;
  //   USDC_TOKEN.mint(
  //     address(BUIDL_USDC_REDEMPTION_FAILED),
  //     DEFAULT_GSM_BUIDL_AMOUNT + bufferForAdditionalTransfer
  //   );

  //   // Supply assets to another user
  //   ghoFaucet(BOB, expectedGhoSold + buyFee);
  //   vm.startPrank(BOB);
  //   GHO_TOKEN.approve(address(gsmConverter), expectedGhoSold + buyFee);

  //   // Invalid redemption of USDC
  //   vm.expectRevert('INVALID_REDEMPTION');
  //   gsmConverter.buyAsset(DEFAULT_GSM_BUIDL_AMOUNT, BOB);
  //   vm.stopPrank();
  // }

  function testBuyAssetWithSig() public {
    (gsmConverterSignerAddr, gsmConverterSignerKey) = makeAddrAndKey('randomString');

    uint256 deadline = block.timestamp + 1 hours;

    uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    (uint256 expectedRedeemedAssetAmount, uint256 expectedGhoSold, , ) = GHO_BUIDL_GSM
      .getGhoAmountForBuyAsset(DEFAULT_GSM_BUIDL_AMOUNT);

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
    ghoFaucet(gsmConverterSignerAddr, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.prank(gsmConverterSignerAddr);
    GHO_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_GHO_AMOUNT + buyFee);

    assertEq(
      GSM_CONVERTER.nonces(gsmConverterSignerAddr),
      0,
      'Unexpected before gsmConverterSignerAddr nonce'
    );

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GSM_CONVERTER.DOMAIN_SEPARATOR(),
        GSM_CONVERTER_BUY_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(
          gsmConverterSignerAddr,
          DEFAULT_GSM_BUIDL_AMOUNT,
          gsmConverterSignerAddr,
          GSM_CONVERTER.nonces(gsmConverterSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmConverterSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmConverterSignerAddr != BOB, 'Signer is the same as Bob');

    vm.prank(BOB);
    // Buy assets via Redemption of USDC
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit BuyAssetThroughRedemption(
      gsmConverterSignerAddr,
      gsmConverterSignerAddr,
      expectedRedeemedAssetAmount,
      expectedGhoSold
    );
    (uint256 redeemedUSDCAmount, uint256 ghoSold) = GSM_CONVERTER.buyAssetWithSig(
      gsmConverterSignerAddr,
      DEFAULT_GSM_BUIDL_AMOUNT,
      gsmConverterSignerAddr,
      deadline,
      signature
    );

    assertEq(ghoSold, expectedGhoSold, 'Unexpected GHO sold amount');
    assertEq(redeemedUSDCAmount, DEFAULT_GSM_BUIDL_AMOUNT, 'Unexpected redeemed buyAsset amount');
    assertEq(
      USDC_TOKEN.balanceOf(gsmConverterSignerAddr),
      DEFAULT_GSM_BUIDL_AMOUNT,
      'Unexpected buyer final USDC balance'
    );
    assertEq(USDC_TOKEN.balanceOf(address(GHO_BUIDL_GSM)), 0, 'Unexpected GSM final USDC balance');
    assertEq(
      USDC_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected converter final USDC balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(gsmConverterSignerAddr)),
      0,
      'Unexpected buyer final GHO balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      GHO_GSM_FIXED_FEE_STRATEGY.getSellFee(DEFAULT_GSM_GHO_AMOUNT) + buyFee,
      'Unexpected GSM final GHO balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(gsmConverterSignerAddr),
      0,
      'Unexpected buyer final BUIDL balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      0,
      'Unexpected GSM final BUIDL balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final BUIDL balance'
    );
  }

  function testBuyAssetWithSigExactDeadline() public {
    // EIP-2612 states the execution must be allowed in case deadline is equal to block.timestamp
    (gsmConverterSignerAddr, gsmConverterSignerKey) = makeAddrAndKey('randomString');

    uint256 deadline = block.timestamp;

    uint256 buyFee = GHO_GSM_FIXED_FEE_STRATEGY.getBuyFee(DEFAULT_GSM_GHO_AMOUNT);
    (uint256 expectedRedeemedAssetAmount, uint256 expectedGhoSold, , ) = GHO_BUIDL_GSM
      .getGhoAmountForBuyAsset(DEFAULT_GSM_BUIDL_AMOUNT);

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
    ghoFaucet(gsmConverterSignerAddr, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.prank(gsmConverterSignerAddr);
    GHO_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_GHO_AMOUNT + buyFee);

    assertEq(
      GSM_CONVERTER.nonces(gsmConverterSignerAddr),
      0,
      'Unexpected before gsmConverterSignerAddr nonce'
    );

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GSM_CONVERTER.DOMAIN_SEPARATOR(),
        GSM_CONVERTER_BUY_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(
          gsmConverterSignerAddr,
          DEFAULT_GSM_BUIDL_AMOUNT,
          gsmConverterSignerAddr,
          GSM_CONVERTER.nonces(gsmConverterSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmConverterSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmConverterSignerAddr != BOB, 'Signer is the same as Bob');

    vm.prank(BOB);
    // Buy assets via Redemption of USDC
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit BuyAssetThroughRedemption(
      gsmConverterSignerAddr,
      gsmConverterSignerAddr,
      expectedRedeemedAssetAmount,
      expectedGhoSold
    );
    (uint256 redeemedUSDCAmount, uint256 ghoSold) = GSM_CONVERTER.buyAssetWithSig(
      gsmConverterSignerAddr,
      DEFAULT_GSM_BUIDL_AMOUNT,
      gsmConverterSignerAddr,
      deadline,
      signature
    );

    assertEq(ghoSold, expectedGhoSold, 'Unexpected GHO sold amount');
    assertEq(redeemedUSDCAmount, DEFAULT_GSM_BUIDL_AMOUNT, 'Unexpected redeemed buyAsset amount');
    assertEq(
      USDC_TOKEN.balanceOf(gsmConverterSignerAddr),
      DEFAULT_GSM_BUIDL_AMOUNT,
      'Unexpected buyer final USDC balance'
    );
    assertEq(USDC_TOKEN.balanceOf(address(GHO_BUIDL_GSM)), 0, 'Unexpected GSM final USDC balance');
    assertEq(
      USDC_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected converter final USDC balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(gsmConverterSignerAddr)),
      0,
      'Unexpected buyer final GHO balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      GHO_GSM_FIXED_FEE_STRATEGY.getSellFee(DEFAULT_GSM_GHO_AMOUNT) + buyFee,
      'Unexpected GSM final GHO balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final GHO balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(gsmConverterSignerAddr),
      0,
      'Unexpected buyer final BUIDL balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      0,
      'Unexpected GSM final BUIDL balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final BUIDL balance'
    );
  }

  function testFuzzMinAmountBuyAssetWithSig(uint minAssetAmount) public {
    minAssetAmount = bound(minAssetAmount, 1, DEFAULT_GSM_BUIDL_AMOUNT * 1000);

    (gsmConverterSignerAddr, gsmConverterSignerKey) = makeAddrAndKey('randomString');

    uint256 deadline = block.timestamp + 1 hours;
    (
      uint256 expectedRedeemedAssetAmount,
      uint256 expectedGhoSold,
      uint256 buyFee,
      uint256 sellFee
    ) = _getBuySellFees(minAssetAmount);

    // Supply BUIDL assets to the BUIDL GSM first
    vm.prank(FAUCET);
    BUIDL_TOKEN.mint(ALICE, expectedRedeemedAssetAmount);
    vm.startPrank(ALICE);
    BUIDL_TOKEN.approve(address(GHO_BUIDL_GSM), expectedRedeemedAssetAmount);
    GHO_BUIDL_GSM.sellAsset(expectedRedeemedAssetAmount, ALICE);
    vm.stopPrank();

    // Supply USDC to the Redemption contract
    vm.prank(FAUCET);
    USDC_TOKEN.mint(address(BUIDL_USDC_REDEMPTION), expectedRedeemedAssetAmount);

    // Supply assets to another user
    ghoFaucet(gsmConverterSignerAddr, expectedGhoSold);
    vm.prank(gsmConverterSignerAddr);
    GHO_TOKEN.approve(address(GSM_CONVERTER), expectedGhoSold);

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GSM_CONVERTER.DOMAIN_SEPARATOR(),
        GSM_CONVERTER_BUY_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(
          gsmConverterSignerAddr,
          minAssetAmount,
          gsmConverterSignerAddr,
          GSM_CONVERTER.nonces(gsmConverterSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmConverterSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmConverterSignerAddr != BOB, 'Signer is the same as Bob');

    vm.prank(BOB);
    // Buy assets via Redemption of USDC
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit BuyAssetThroughRedemption(
      gsmConverterSignerAddr,
      gsmConverterSignerAddr,
      expectedRedeemedAssetAmount,
      expectedGhoSold
    );
    GSM_CONVERTER.buyAssetWithSig(
      gsmConverterSignerAddr,
      minAssetAmount,
      gsmConverterSignerAddr,
      deadline,
      signature
    );

    assertEq(
      USDC_TOKEN.balanceOf(gsmConverterSignerAddr),
      minAssetAmount,
      'Unexpected buyer final USDC balance'
    );
    assertEq(USDC_TOKEN.balanceOf(address(GHO_BUIDL_GSM)), 0, 'Unexpected GSM final USDC balance');
    assertEq(
      USDC_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final USDC balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(gsmConverterSignerAddr)),
      0,
      'Unexpected buyer final GHO balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      sellFee + buyFee,
      'Unexpected GSM final GHO balance'
    );
    assertEq(GHO_TOKEN.balanceOf(address(GSM_CONVERTER)), 0, 'Unexpected GSM final GHO balance');
    assertEq(
      BUIDL_TOKEN.balanceOf(gsmConverterSignerAddr),
      0,
      'Unexpected buyer final BUIDL balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GHO_BUIDL_GSM)),
      0,
      'Unexpected GSM final BUIDL balance'
    );
    assertEq(
      BUIDL_TOKEN.balanceOf(address(GSM_CONVERTER)),
      0,
      'Unexpected GSM_CONVERTER final BUIDL balance'
    );
  }

  function testRevertBuyAssetWithSigExpiredSignature() public {
    // EIP-2612 states the execution must be allowed in case deadline is equal to block.timestamp
    (gsmConverterSignerAddr, gsmConverterSignerKey) = makeAddrAndKey('randomString');

    uint256 deadline = block.timestamp - 1;
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
    ghoFaucet(gsmConverterSignerAddr, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.prank(gsmConverterSignerAddr);
    GHO_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_GHO_AMOUNT + buyFee);

    assertEq(
      GSM_CONVERTER.nonces(gsmConverterSignerAddr),
      0,
      'Unexpected before gsmConverterSignerAddr nonce'
    );

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GSM_CONVERTER.DOMAIN_SEPARATOR(),
        GSM_CONVERTER_BUY_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(
          gsmConverterSignerAddr,
          DEFAULT_GSM_BUIDL_AMOUNT,
          gsmConverterSignerAddr,
          GSM_CONVERTER.nonces(gsmConverterSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmConverterSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmConverterSignerAddr != BOB, 'Signer is the same as Bob');

    vm.prank(BOB);
    vm.expectRevert('SIGNATURE_DEADLINE_EXPIRED');
    GSM_CONVERTER.buyAssetWithSig(
      gsmConverterSignerAddr,
      DEFAULT_GSM_BUIDL_AMOUNT,
      gsmConverterSignerAddr,
      deadline,
      signature
    );
  }

  function testRevertBuyAssetWithSigInvalidSignature() public {
    // EIP-2612 states the execution must be allowed in case deadline is equal to block.timestamp
    (gsmConverterSignerAddr, gsmConverterSignerKey) = makeAddrAndKey('randomString');

    uint256 deadline = block.timestamp + 1;
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
    ghoFaucet(gsmConverterSignerAddr, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.prank(gsmConverterSignerAddr);
    GHO_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_GHO_AMOUNT + buyFee);

    assertEq(
      GSM_CONVERTER.nonces(gsmConverterSignerAddr),
      0,
      'Unexpected before gsmConverterSignerAddr nonce'
    );

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GSM_CONVERTER.DOMAIN_SEPARATOR(),
        GSM_CONVERTER_BUY_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(
          gsmConverterSignerAddr,
          DEFAULT_GSM_BUIDL_AMOUNT,
          gsmConverterSignerAddr,
          GSM_CONVERTER.nonces(gsmConverterSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmConverterSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmConverterSignerAddr != BOB, 'Signer is the same as Bob');

    vm.prank(BOB);
    vm.expectRevert('SIGNATURE_INVALID');
    GSM_CONVERTER.buyAssetWithSig(
      BOB, // invalid signer
      DEFAULT_GSM_BUIDL_AMOUNT,
      gsmConverterSignerAddr,
      deadline,
      signature
    );
  }

  function testRevertBuyAssetWithSigInvalidAmount() public {
    // EIP-2612 states the execution must be allowed in case deadline is equal to block.timestamp
    (gsmConverterSignerAddr, gsmConverterSignerKey) = makeAddrAndKey('randomString');

    uint256 deadline = block.timestamp + 1;
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
    ghoFaucet(gsmConverterSignerAddr, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.prank(gsmConverterSignerAddr);
    GHO_TOKEN.approve(address(GSM_CONVERTER), DEFAULT_GSM_GHO_AMOUNT + buyFee);

    assertEq(
      GSM_CONVERTER.nonces(gsmConverterSignerAddr),
      0,
      'Unexpected before gsmConverterSignerAddr nonce'
    );

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GSM_CONVERTER.DOMAIN_SEPARATOR(),
        GSM_CONVERTER_BUY_ASSET_WITH_SIG_TYPEHASH,
        abi.encode(
          gsmConverterSignerAddr,
          DEFAULT_GSM_BUIDL_AMOUNT,
          gsmConverterSignerAddr,
          GSM_CONVERTER.nonces(gsmConverterSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmConverterSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmConverterSignerAddr != BOB, 'Signer is the same as Bob');

    vm.prank(BOB);
    vm.expectRevert('SIGNATURE_INVALID');
    GSM_CONVERTER.buyAssetWithSig(
      gsmConverterSignerAddr,
      DEFAULT_GSM_BUIDL_AMOUNT + 1, // invalid amount
      gsmConverterSignerAddr,
      deadline,
      signature
    );
  }

  function testRescueTokens() public {
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
    vm.expectRevert('INVALID_AMOUNT');
    GSM_CONVERTER.rescueTokens(address(WETH), ALICE, 0);
  }

  function testRevertRescueTokensInsufficientAmount() public {
    vm.expectRevert();
    GSM_CONVERTER.rescueTokens(address(WETH), ALICE, 1);
  }

  function testRescueGhoTokens() public {
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
    vm.prank(FAUCET);
    USDC_TOKEN.mint(address(GSM_CONVERTER), DEFAULT_GSM_USDC_AMOUNT);

    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected USDC balance before');
    vm.expectEmit(true, true, true, true, address(GSM_CONVERTER));
    emit TokensRescued(address(USDC_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    GSM_CONVERTER.rescueTokens(address(USDC_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    assertEq(USDC_TOKEN.balanceOf(ALICE), DEFAULT_GSM_USDC_AMOUNT, 'Unexpected USDC balance after');
  }

  function testRescueIssuedTokens() public {
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

  function _upgradeToGsmFailedBuyAssetGhoAmount() internal {
    address gsmFailed = address(
      new MockGsmFailedGetGhoAmountForBuyAsset(
        address(GHO_TOKEN),
        address(BUIDL_TOKEN),
        address(GHO_BUIDL_GSM_FIXED_PRICE_STRATEGY)
      )
    );
    bytes memory data = abi.encodeWithSelector(
      MockGsmFailedGetGhoAmountForBuyAsset.initialize.selector,
      address(this),
      TREASURY,
      DEFAULT_GSM_USDC_EXPOSURE
    );

    vm.prank(SHORT_EXECUTOR);
    AdminUpgradeabilityProxy(payable(address(GHO_BUIDL_GSM))).upgradeToAndCall(gsmFailed, data);
  }

  function _upgradeToGsmFailedBuyAssetRemainingGhoBalance() internal {
    address gsmFailed = address(
      new MockGsmFailedBuyAssetRemainingGhoBalance(
        address(GHO_TOKEN),
        address(BUIDL_TOKEN),
        address(GHO_BUIDL_GSM_FIXED_PRICE_STRATEGY)
      )
    );
    bytes memory data = abi.encodeWithSelector(
      MockGsmFailedBuyAssetRemainingGhoBalance.initialize.selector,
      address(this),
      TREASURY,
      DEFAULT_GSM_USDC_EXPOSURE
    );

    vm.prank(SHORT_EXECUTOR);
    AdminUpgradeabilityProxy(payable(address(GHO_BUIDL_GSM))).upgradeToAndCall(gsmFailed, data);
  }

  function _upgradeToGsmFailedSellAssetRemainingGhoBalance() internal {
    address gsmFailed = address(
      new MockGsmFailedSellAssetRemainingGhoBalance(
        address(GHO_TOKEN),
        address(BUIDL_TOKEN),
        address(GHO_BUIDL_GSM_FIXED_PRICE_STRATEGY)
      )
    );
    bytes memory data = abi.encodeWithSelector(
      MockGsmFailedSellAssetRemainingGhoBalance.initialize.selector,
      address(this),
      TREASURY,
      DEFAULT_GSM_USDC_EXPOSURE
    );

    vm.prank(SHORT_EXECUTOR);
    AdminUpgradeabilityProxy(payable(address(GHO_BUIDL_GSM))).upgradeToAndCall(gsmFailed, data);
  }

  function _getBuySellFees(
    uint256 amount
  )
    internal
    returns (
      uint256 expectedRedeemedAssetAmount,
      uint256 expectedGhoSold,
      uint256 buyFee,
      uint256 sell
    )
  {
    (expectedRedeemedAssetAmount, expectedGhoSold, , buyFee) = GHO_BUIDL_GSM
      .getGhoAmountForBuyAsset(amount);
    (, , , sell) = GHO_BUIDL_GSM.getGhoAmountForSellAsset(amount);
  }
}

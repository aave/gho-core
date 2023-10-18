// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestGhoBase.t.sol';

contract TestGsm is TestGhoBase {
  using PercentageMath for uint256;
  using PercentageMath for uint128;

  address internal gsmSignerAddr;
  uint256 internal gsmSignerKey;

  function setUp() public {
    (gsmSignerAddr, gsmSignerKey) = makeAddrAndKey('gsmSigner');
  }

  function testConstructor() public {
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(USDC_TOKEN));
    assertEq(gsm.GHO_TOKEN(), address(GHO_TOKEN), 'Unexpected GHO token address');
    assertEq(gsm.UNDERLYING_ASSET(), address(USDC_TOKEN), 'Unexpected underlying asset address');
  }

  function testInitialize() public {
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(USDC_TOKEN));
    vm.expectEmit(true, true, true, true);
    emit RoleGranted(DEFAULT_ADMIN_ROLE, address(this), address(this));
    vm.expectEmit(true, true, false, true);
    emit PriceStrategyUpdated(address(0), address(GHO_GSM_FIXED_PRICE_STRATEGY));
    vm.expectEmit(true, true, false, true);
    emit ExposureCapUpdated(0, DEFAULT_GSM_USDC_EXPOSURE);
    gsm.initialize(
      address(this),
      TREASURY,
      address(GHO_GSM_FIXED_PRICE_STRATEGY),
      DEFAULT_GSM_USDC_EXPOSURE
    );
    assertEq(
      gsm.getPriceStrategy(),
      address(GHO_GSM_FIXED_PRICE_STRATEGY),
      'Unexpected price strategy'
    );
  }

  function testRevertInitializeTwice() public {
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(USDC_TOKEN));
    gsm.initialize(
      address(this),
      TREASURY,
      address(GHO_GSM_FIXED_PRICE_STRATEGY),
      DEFAULT_GSM_USDC_EXPOSURE
    );
    vm.expectRevert('Contract instance has already been initialized');
    gsm.initialize(
      address(this),
      TREASURY,
      address(GHO_GSM_FIXED_PRICE_STRATEGY),
      DEFAULT_GSM_USDC_EXPOSURE
    );
  }

  function testSellAssetZeroFee() public {
    vm.expectEmit(true, true, false, true, address(GHO_GSM));
    emit FeeStrategyUpdated(address(GHO_GSM_FIXED_FEE_STRATEGY), address(0));
    GHO_GSM.updateFeeStrategy(address(0));

    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, 0);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();
    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), DEFAULT_GSM_GHO_AMOUNT, 'Unexpected final GHO balance');
  }

  function testSellAsset() public {
    uint256 fee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = DEFAULT_GSM_GHO_AMOUNT - fee;

    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, fee);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoOut, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), fee, 'Unexpected GSM GHO balance');
    assertEq(
      GHO_GSM.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected available underlying exposure'
    );
    assertEq(
      GHO_GSM.getAvailableLiquidity(),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected available liquidity'
    );
  }

  function testSellAssetSendToOther() public {
    uint256 fee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = DEFAULT_GSM_GHO_AMOUNT - fee;

    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, BOB, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, fee);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), 0, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(BOB), ghoOut, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), fee, 'Unexpected GSM GHO balance');
  }

  function testSellAssetWithSig() public {
    uint256 deadline = block.timestamp + 1 hours;
    uint256 fee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = DEFAULT_GSM_GHO_AMOUNT - fee;

    vm.prank(FAUCET);
    USDC_TOKEN.mint(gsmSignerAddr, DEFAULT_GSM_USDC_AMOUNT);

    vm.prank(gsmSignerAddr);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);

    assertEq(GHO_GSM.nonces(gsmSignerAddr), 0, 'Unexpected before gsmSignerAddr nonce');

    bytes32 sellAssetWithSigTypehash = keccak256(
      'SellAssetWithSig(address originator,uint128 amount,address receiver,uint256 nonce,uint256 deadline)'
    );
    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        sellAssetWithSigTypehash,
        abi.encode(
          gsmSignerAddr,
          DEFAULT_GSM_USDC_AMOUNT,
          gsmSignerAddr,
          GHO_GSM.nonces(gsmSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmSignerAddr != ALICE, 'Signer is the same as Alice');

    // Send the signature via another user
    vm.prank(ALICE);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(
      gsmSignerAddr,
      gsmSignerAddr,
      DEFAULT_GSM_USDC_AMOUNT,
      DEFAULT_GSM_GHO_AMOUNT,
      fee
    );
    GHO_GSM.sellAssetWithSig(
      gsmSignerAddr,
      DEFAULT_GSM_USDC_AMOUNT,
      gsmSignerAddr,
      deadline,
      signature
    );

    assertEq(GHO_GSM.nonces(gsmSignerAddr), 1, 'Unexpected final gsmSignerAddr nonce');
    assertEq(USDC_TOKEN.balanceOf(gsmSignerAddr), 0, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(gsmSignerAddr), ghoOut, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), fee, 'Unexpected GSM GHO balance');
  }

  function testRevertSellAssetWithSigExpiredSignature() public {
    uint256 deadline = block.timestamp - 1;

    bytes32 sellAssetWithSigTypehash = keccak256(
      'SellAssetWithSig(address originator,uint128 amount,address receiver,uint256 nonce,uint256 deadline)'
    );
    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        sellAssetWithSigTypehash,
        abi.encode(
          gsmSignerAddr,
          DEFAULT_GSM_USDC_AMOUNT,
          gsmSignerAddr,
          GHO_GSM.nonces(gsmSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmSignerAddr != ALICE, 'Signer is the same as Alice');

    // Send the signature via another user
    vm.prank(ALICE);
    vm.expectRevert('SIGNATURE_DEADLINE_EXPIRED');
    GHO_GSM.sellAssetWithSig(
      gsmSignerAddr,
      DEFAULT_GSM_USDC_AMOUNT,
      gsmSignerAddr,
      deadline,
      signature
    );
  }

  function testRevertSellAssetWithSigInvalidSignature() public {
    uint256 deadline = block.timestamp + 1 hours;

    bytes32 sellAssetWithSigTypehash = keccak256(
      'SellAssetWithSig(address originator,uint128 amount,address receiver,uint256 nonce,uint256 deadline)'
    );
    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        sellAssetWithSigTypehash,
        abi.encode(
          gsmSignerAddr,
          DEFAULT_GSM_USDC_AMOUNT,
          gsmSignerAddr,
          GHO_GSM.nonces(gsmSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmSignerAddr != ALICE, 'Signer is the same as Alice');

    // Send the signature via another user
    vm.prank(ALICE);
    vm.expectRevert('SIGNATURE_INVALID');
    GHO_GSM.sellAssetWithSig(ALICE, DEFAULT_GSM_USDC_AMOUNT, ALICE, deadline, signature);
  }

  function testRevertSellAssetZeroAmount() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_AMOUNT');
    GHO_GSM.sellAsset(0, ALICE);
  }

  function testRevertSellAssetNoAsset() public {
    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectRevert('ERC20: transfer amount exceeds balance');
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();
  }

  function testRevertSellAssetNoAllowance() public {
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.prank(ALICE);
    vm.expectRevert('ERC20: transfer amount exceeds allowance');
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
  }

  function testRevertSellAssetNoBucketCap() public {
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(USDC_TOKEN));
    gsm.initialize(
      address(this),
      TREASURY,
      address(GHO_GSM_FIXED_PRICE_STRATEGY),
      DEFAULT_GSM_USDC_EXPOSURE
    );
    GHO_TOKEN.addFacilitator(address(gsm), 'GSM Modified Bucket Cap', DEFAULT_CAPACITY - 1);
    uint128 defaultCapInUsdc = uint128(DEFAULT_CAPACITY / (10 ** (18 - USDC_TOKEN.decimals())));

    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, defaultCapInUsdc);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(gsm), defaultCapInUsdc);
    vm.expectRevert('FACILITATOR_BUCKET_CAPACITY_EXCEEDED');
    gsm.sellAsset(defaultCapInUsdc, ALICE);
    vm.stopPrank();
  }

  function testRevertSellAssetTooMuchUnderlyingExposure() public {
    Gsm gsm = new Gsm(address(GHO_TOKEN), address(USDC_TOKEN));
    gsm.initialize(
      address(this),
      TREASURY,
      address(GHO_GSM_FIXED_PRICE_STRATEGY),
      DEFAULT_GSM_USDC_EXPOSURE - 1
    );
    GHO_TOKEN.addFacilitator(address(gsm), 'GSM Modified Exposure Cap', DEFAULT_CAPACITY);

    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_EXPOSURE);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(gsm), DEFAULT_GSM_USDC_EXPOSURE);
    vm.expectRevert('EXOGENOUS_ASSET_EXPOSURE_TOO_HIGH');
    gsm.sellAsset(DEFAULT_GSM_USDC_EXPOSURE, ALICE);
    vm.stopPrank();
  }

  function testGetGhoAmountForSellAsset() public {
    (uint256 ghoBought, uint256 grossAmount, uint256 fee) = GHO_GSM.getGhoAmountForSellAsset(
      DEFAULT_GSM_USDC_AMOUNT
    );

    _sellAsset(GHO_GSM, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    assertEq(ghoBought + fee, grossAmount, 'Unexpected GHO gross amount');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoBought, 'Unexpected GHO bought amount');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), fee, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 grossAmount2, uint256 fee2) = GHO_GSM.getAssetAmountForSellAsset(
      ghoBought
    );
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected estimation of sold assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testGetGhoAmountForSellAssetWithZeroFee() public {
    GHO_GSM.updateFeeStrategy(address(0));

    (uint256 ghoBought, uint256 grossAmount, uint256 fee) = GHO_GSM.getGhoAmountForSellAsset(
      DEFAULT_GSM_USDC_AMOUNT
    );
    assertEq(fee, 0, 'Unexpected GHO fee amount');

    _sellAsset(GHO_GSM, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    assertEq(ghoBought, grossAmount, 'Unexpected GHO gross amount');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoBought, 'Unexpected GHO bought amount');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), 0, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 grossAmount2, uint256 fee2) = GHO_GSM.getAssetAmountForSellAsset(
      ghoBought
    );
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected estimation of sold assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testGetGhoAmountForSellAssetWithZeroAmount() public {
    (uint256 ghoBought, uint256 grossAmount, uint256 fee) = GHO_GSM.getGhoAmountForSellAsset(0);
    assertEq(ghoBought, 0, 'Unexpected GHO bought amount');
    assertEq(grossAmount, 0, 'Unexpected GHO gross amount');
    assertEq(fee, 0, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 grossAmount2, uint256 fee2) = GHO_GSM.getAssetAmountForSellAsset(
      ghoBought
    );
    assertEq(assetAmount, 0, 'Unexpected estimation of sold assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testBuyAssetZeroFee() public {
    vm.expectEmit(true, true, false, true, address(GHO_GSM));
    emit FeeStrategyUpdated(address(GHO_GSM_FIXED_FEE_STRATEGY), address(0));
    GHO_GSM.updateFeeStrategy(address(0));

    // Supply assets to the GSM first
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, 0);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    // Buy assets as another user
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit BuyAsset(BOB, BOB, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, 0);
    GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    assertEq(USDC_TOKEN.balanceOf(BOB), DEFAULT_GSM_USDC_AMOUNT, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), DEFAULT_GSM_GHO_AMOUNT, 'Unexpected final GHO balance');
  }

  function testBuyAsset() public {
    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);
    uint256 ghoOut = DEFAULT_GSM_GHO_AMOUNT - sellFee;

    // Supply assets to the GSM first
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, sellFee);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    // Buy assets as another user
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit BuyAsset(BOB, BOB, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT + buyFee, buyFee);
    GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    assertEq(USDC_TOKEN.balanceOf(BOB), DEFAULT_GSM_USDC_AMOUNT, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoOut, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), sellFee + buyFee, 'Unexpected GSM GHO balance');
    assertEq(
      GHO_GSM.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE,
      'Unexpected available underlying exposure'
    );
    assertEq(GHO_GSM.getAvailableLiquidity(), 0, 'Unexpected available liquidity');
  }

  function testBuyAssetSendToOther() public {
    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);
    uint256 ghoOut = DEFAULT_GSM_GHO_AMOUNT - sellFee;

    // Supply assets to the GSM first
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, sellFee);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    // Buy assets as another user
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit BuyAsset(BOB, CHARLES, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT + buyFee, buyFee);
    GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, CHARLES);
    vm.stopPrank();

    assertEq(USDC_TOKEN.balanceOf(BOB), 0, 'Unexpected final USDC balance');
    assertEq(
      USDC_TOKEN.balanceOf(CHARLES),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected final USDC balance'
    );
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoOut, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), sellFee + buyFee, 'Unexpected GSM GHO balance');
  }

  function testBuyAssetWithSig() public {
    uint256 deadline = block.timestamp + 1 hours;
    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);
    uint256 ghoOut = DEFAULT_GSM_GHO_AMOUNT - sellFee;

    // Supply assets to the GSM first
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, sellFee);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertTrue(gsmSignerAddr != ALICE, 'Signer is the same as Alice');

    // Buy assets as another user
    ghoFaucet(gsmSignerAddr, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.prank(gsmSignerAddr);
    GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT + buyFee);

    assertEq(GHO_GSM.nonces(gsmSignerAddr), 0, 'Unexpected before gsmSignerAddr nonce');

    bytes32 buyAssetWithSigTypehash = keccak256(
      'BuyAssetWithSig(address originator,uint128 amount,address receiver,uint256 nonce,uint256 deadline)'
    );
    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        buyAssetWithSigTypehash,
        abi.encode(
          gsmSignerAddr,
          DEFAULT_GSM_USDC_AMOUNT,
          gsmSignerAddr,
          GHO_GSM.nonces(gsmSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmSignerAddr != BOB, 'Signer is the same as Bob');

    vm.prank(BOB);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit BuyAsset(
      gsmSignerAddr,
      gsmSignerAddr,
      DEFAULT_GSM_USDC_AMOUNT,
      DEFAULT_GSM_GHO_AMOUNT + buyFee,
      buyFee
    );
    GHO_GSM.buyAssetWithSig(
      gsmSignerAddr,
      DEFAULT_GSM_USDC_AMOUNT,
      gsmSignerAddr,
      deadline,
      signature
    );

    assertEq(GHO_GSM.nonces(gsmSignerAddr), 1, 'Unexpected final gsmSignerAddr nonce');
    assertEq(
      USDC_TOKEN.balanceOf(gsmSignerAddr),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected final USDC balance'
    );
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoOut, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), sellFee + buyFee, 'Unexpected GSM GHO balance');
  }

  function testBuyThenSellAtMaximumBucketCapacity() public {
    // Use zero fees to simplify amount calculations
    vm.expectEmit(true, true, false, true, address(GHO_GSM));
    emit FeeStrategyUpdated(address(GHO_GSM_FIXED_FEE_STRATEGY), address(0));
    GHO_GSM.updateFeeStrategy(address(0));

    // Supply assets to the GSM first
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_EXPOSURE);
    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_EXPOSURE);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_EXPOSURE, DEFAULT_CAPACITY, 0);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_EXPOSURE, ALICE);

    (uint256 ghoCapacity, uint256 ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM));
    assertEq(ghoLevel, ghoCapacity, 'Unexpected GHO bucket level after initial sell');
    assertEq(
      GHO_TOKEN.balanceOf(ALICE),
      DEFAULT_CAPACITY,
      'Unexpected Alice GHO balance after sell'
    );

    // Buy 1 of the underlying
    GHO_TOKEN.approve(address(GHO_GSM), 1e18);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit BuyAsset(ALICE, ALICE, 1e6, 1e18, 0);
    GHO_GSM.buyAsset(1e6, ALICE);

    (, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM));
    assertEq(ghoLevel, DEFAULT_CAPACITY - 1e18, 'Unexpected GHO bucket level after buy');
    assertEq(
      GHO_TOKEN.balanceOf(ALICE),
      DEFAULT_CAPACITY - 1e18,
      'Unexpected Alice GHO balance after buy'
    );
    assertEq(USDC_TOKEN.balanceOf(ALICE), 1e6, 'Unexpected Alice USDC balance after buy');

    // Sell 1 of the underlying
    USDC_TOKEN.approve(address(GHO_GSM), 1e6);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, ALICE, 1e6, 1e18, 0);
    GHO_GSM.sellAsset(1e6, ALICE);
    vm.stopPrank();

    (ghoCapacity, ghoLevel) = GHO_TOKEN.getFacilitatorBucket(address(GHO_GSM));
    assertEq(ghoLevel, ghoCapacity, 'Unexpected GHO bucket level after second sell');
    assertEq(
      GHO_TOKEN.balanceOf(ALICE),
      DEFAULT_CAPACITY,
      'Unexpected Alice GHO balance after second sell'
    );
    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected Alice USDC balance after second sell');
  }

  function testRevertBuyAssetWithSigExpiredSignature() public {
    uint256 deadline = block.timestamp - 1;

    bytes32 buyAssetWithSigTypehash = keccak256(
      'BuyAssetWithSig(address originator,uint128 amount,address receiver,uint256 nonce,uint256 deadline)'
    );
    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        buyAssetWithSigTypehash,
        abi.encode(
          gsmSignerAddr,
          DEFAULT_GSM_USDC_AMOUNT,
          gsmSignerAddr,
          GHO_GSM.nonces(gsmSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmSignerAddr != BOB, 'Signer is the same as Bob');

    vm.prank(BOB);
    vm.expectRevert('SIGNATURE_DEADLINE_EXPIRED');
    GHO_GSM.buyAssetWithSig(
      gsmSignerAddr,
      DEFAULT_GSM_USDC_AMOUNT,
      gsmSignerAddr,
      deadline,
      signature
    );
  }

  function testRevertBuyAssetWithSigInvalidSignature() public {
    uint256 deadline = block.timestamp + 1 hours;

    bytes32 buyAssetWithSigTypehash = keccak256(
      'BuyAssetWithSig(address originator,uint128 amount,address receiver,uint256 nonce,uint256 deadline)'
    );
    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        buyAssetWithSigTypehash,
        abi.encode(
          gsmSignerAddr,
          DEFAULT_GSM_USDC_AMOUNT,
          gsmSignerAddr,
          GHO_GSM.nonces(gsmSignerAddr),
          deadline
        )
      )
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmSignerKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);

    assertTrue(gsmSignerAddr != BOB, 'Signer is the same as Bob');

    vm.prank(BOB);
    vm.expectRevert('SIGNATURE_INVALID');
    GHO_GSM.buyAssetWithSig(BOB, DEFAULT_GSM_USDC_AMOUNT, gsmSignerAddr, deadline, signature);
  }

  function testRevertBuyAssetZeroAmount() public {
    vm.prank(ALICE);
    vm.expectRevert('INVALID_AMOUNT');
    GHO_GSM.buyAsset(0, ALICE);
  }

  function testRevertBuyAssetNoGHO() public {
    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);

    // Supply assets to the GSM first
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, sellFee);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.expectRevert(stdError.arithmeticError);
    GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();
  }

  function testRevertBuyAssetNoAllowance() public {
    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);

    // Supply assets to the GSM first
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, sellFee);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    vm.expectRevert(stdError.arithmeticError);
    GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();
  }

  function testGetGhoAmountForBuyAsset() public {
    (uint256 ghoSold, uint256 grossAmount, uint256 fee) = GHO_GSM.getGhoAmountForBuyAsset(
      DEFAULT_GSM_USDC_AMOUNT
    );

    uint256 topUpAmount = 1_000_000e18;
    ghoFaucet(ALICE, topUpAmount);

    _sellAsset(GHO_GSM, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    uint256 ghoBalanceBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 ghoFeesBefore = GHO_TOKEN.balanceOf(address(GHO_GSM));

    vm.startPrank(ALICE);
    GHO_TOKEN.approve(address(GHO_GSM), type(uint256).max);
    GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(ghoSold - fee, grossAmount, 'Unexpected GHO gross sold amount');
    assertEq(ghoBalanceBefore - GHO_TOKEN.balanceOf(ALICE), ghoSold, 'Unexpected GHO sold amount');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM)) - ghoFeesBefore,
      fee,
      'Unexpected GHO fee amount'
    );

    (uint256 assetAmount, uint256 grossAmount2, uint256 fee2) = GHO_GSM.getAssetAmountForBuyAsset(
      ghoSold
    );
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected estimation of bought assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testGetGhoAmountForBuyAssetWithZeroFee() public {
    GHO_GSM.updateFeeStrategy(address(0));

    (uint256 ghoSold, uint256 grossAmount, uint256 fee) = GHO_GSM.getGhoAmountForBuyAsset(
      DEFAULT_GSM_USDC_AMOUNT
    );
    assertEq(fee, 0, 'Unexpected GHO fee amount');

    uint256 topUpAmount = 1_000_000e18;
    ghoFaucet(ALICE, topUpAmount);

    _sellAsset(GHO_GSM, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    uint256 ghoBalanceBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 ghoFeesBefore = GHO_TOKEN.balanceOf(address(GHO_GSM));

    vm.startPrank(ALICE);
    GHO_TOKEN.approve(address(GHO_GSM), type(uint256).max);
    GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(ghoSold, grossAmount, 'Unexpected GHO gross sold amount');
    assertEq(ghoBalanceBefore - GHO_TOKEN.balanceOf(ALICE), ghoSold, 'Unexpected GHO sold amount');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), ghoFeesBefore, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 grossAmount2, uint256 fee2) = GHO_GSM.getAssetAmountForBuyAsset(
      ghoSold
    );
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected estimation of bought assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testGetGhoAmountForBuyAssetWithZeroAmount() public {
    (uint256 ghoSold, uint256 grossAmount, uint256 fee) = GHO_GSM.getGhoAmountForBuyAsset(0);
    assertEq(ghoSold, 0, 'Unexpected GHO sold amount');
    assertEq(grossAmount, 0, 'Unexpected GHO gross amount');
    assertEq(fee, 0, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 grossAmount2, uint256 fee2) = GHO_GSM.getAssetAmountForBuyAsset(
      ghoSold
    );
    assertEq(assetAmount, 0, 'Unexpected estimation of bought assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testSwapFreeze() public {
    assertEq(GHO_GSM.getIsFrozen(), false, 'Unexpected freeze status before');
    vm.prank(address(GHO_GSM_SWAP_FREEZER));
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit SwapFreeze(address(GHO_GSM_SWAP_FREEZER), true);
    GHO_GSM.setSwapFreeze(true);
    assertEq(GHO_GSM.getIsFrozen(), true, 'Unexpected freeze status after');
  }

  function testRevertFreezeNotAuthorized() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_SWAP_FREEZER_ROLE, ALICE));
    vm.prank(ALICE);
    GHO_GSM.setSwapFreeze(true);
  }

  function testRevertSwapFreezeAlreadyFrozen() public {
    vm.startPrank(address(GHO_GSM_SWAP_FREEZER));
    GHO_GSM.setSwapFreeze(true);
    vm.expectRevert('GSM_ALREADY_FROZEN');
    GHO_GSM.setSwapFreeze(true);
    vm.stopPrank();
  }

  function testSwapUnfreeze() public {
    vm.startPrank(address(GHO_GSM_SWAP_FREEZER));
    GHO_GSM.setSwapFreeze(true);
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit SwapFreeze(address(GHO_GSM_SWAP_FREEZER), false);
    GHO_GSM.setSwapFreeze(false);
    vm.stopPrank();
  }

  function testRevertUnfreezeNotAuthorized() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_SWAP_FREEZER_ROLE, ALICE));
    vm.prank(ALICE);
    GHO_GSM.setSwapFreeze(false);
  }

  function testRevertUnfreezeNotFrozen() public {
    vm.prank(address(GHO_GSM_SWAP_FREEZER));
    vm.expectRevert('GSM_ALREADY_UNFROZEN');
    GHO_GSM.setSwapFreeze(false);
  }

  function testRevertBuyAndSellWhenSwapFrozen() public {
    vm.prank(address(GHO_GSM_SWAP_FREEZER));
    GHO_GSM.setSwapFreeze(true);
    vm.expectRevert('GSM_FROZEN_SWAPS_DISABLED');
    GHO_GSM.buyAsset(0, ALICE);
    vm.expectRevert('GSM_FROZEN_SWAPS_DISABLED');
    GHO_GSM.sellAsset(0, ALICE);
  }

  function testUpdateConfigurator() public {
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit RoleGranted(GSM_CONFIGURATOR_ROLE, ALICE, address(this));
    GHO_GSM.grantRole(GSM_CONFIGURATOR_ROLE, ALICE);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit RoleRevoked(GSM_CONFIGURATOR_ROLE, address(this), address(this));
    GHO_GSM.revokeRole(GSM_CONFIGURATOR_ROLE, address(this));
  }

  function testRevertUpdateConfiguratorNotAuthorized() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(DEFAULT_ADMIN_ROLE, ALICE));
    vm.prank(ALICE);
    GHO_GSM.grantRole(GSM_CONFIGURATOR_ROLE, ALICE);
  }

  function testConfiguratorUpdateMethods() public {
    // Alice as configurator
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit RoleGranted(GSM_CONFIGURATOR_ROLE, ALICE, address(this));
    GHO_GSM.grantRole(GSM_CONFIGURATOR_ROLE, ALICE);

    vm.startPrank(address(ALICE));

    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE,
      address(USDC_TOKEN),
      6
    );
    vm.expectEmit(true, true, false, true, address(GHO_GSM));
    emit PriceStrategyUpdated(address(GHO_GSM_FIXED_PRICE_STRATEGY), address(newPriceStrategy));
    GHO_GSM.updatePriceStrategy(address(newPriceStrategy));

    assertEq(
      GHO_GSM.getFeeStrategy(),
      address(GHO_GSM_FIXED_FEE_STRATEGY),
      'Unexpected fee strategy'
    );
    FixedFeeStrategy newFeeStrategy = new FixedFeeStrategy(
      DEFAULT_GSM_BUY_FEE,
      DEFAULT_GSM_SELL_FEE
    );
    vm.expectEmit(true, true, false, true, address(GHO_GSM));
    emit FeeStrategyUpdated(address(GHO_GSM_FIXED_FEE_STRATEGY), address(newFeeStrategy));
    GHO_GSM.updateFeeStrategy(address(newFeeStrategy));
    assertEq(GHO_GSM.getFeeStrategy(), address(newFeeStrategy), 'Unexpected fee strategy');

    vm.expectEmit(true, true, false, true, address(GHO_GSM));
    emit ExposureCapUpdated(DEFAULT_GSM_USDC_EXPOSURE, 0);
    GHO_GSM.updateExposureCap(0);

    vm.stopPrank();
  }

  function testRevertConfiguratorUpdateMethodsNotAuthorized() public {
    vm.startPrank(ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    GHO_GSM.updatePriceStrategy(ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(DEFAULT_ADMIN_ROLE, ALICE));
    GHO_GSM.grantRole(GSM_LIQUIDATOR_ROLE, ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(DEFAULT_ADMIN_ROLE, ALICE));
    GHO_GSM.grantRole(GSM_SWAP_FREEZER_ROLE, ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    GHO_GSM.updateExposureCap(0);
    vm.stopPrank();
  }

  function testRevertUpdatePriceStrategyZeroAddress() public {
    FixedPriceStrategy wrongPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE,
      address(WETH),
      18
    );
    vm.expectRevert('INVALID_PRICE_STRATEGY_FOR_ASSET');
    GHO_GSM.updatePriceStrategy(address(wrongPriceStrategy));
  }

  function testUpdateGhoTreasuryRevertIfZero() public {
    vm.expectRevert(bytes('ZERO_ADDRESS_NOT_VALID'));
    GHO_GSM.updateGhoTreasury(address(0));
  }

  function testUpdateGhoTreasury() public {
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit GhoTreasuryUpdated(TREASURY, ALICE);
    GHO_GSM.updateGhoTreasury(ALICE);

    assertEq(GHO_GSM.getGhoTreasury(), ALICE);
  }

  function testUnauthorizedUpdateGhoTreasuryRevert() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    vm.prank(ALICE);
    GHO_GSM.updateGhoTreasury(ALICE);
  }

  function testRescueTokens() public {
    GHO_GSM.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    vm.prank(FAUCET);
    WETH.mint(address(GHO_GSM), 100e18);
    assertEq(WETH.balanceOf(address(GHO_GSM)), 100e18, 'Unexpected GSM WETH before balance');
    assertEq(WETH.balanceOf(ALICE), 0, 'Unexpected target WETH before balance');
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit TokensRescued(address(WETH), ALICE, 100e18);
    GHO_GSM.rescueTokens(address(WETH), ALICE, 100e18);
    assertEq(WETH.balanceOf(address(GHO_GSM)), 0, 'Unexpected GSM WETH after balance');
    assertEq(WETH.balanceOf(ALICE), 100e18, 'Unexpected target WETH after balance');
  }

  function testRescueGhoTokens() public {
    GHO_GSM.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    ghoFaucet(address(GHO_GSM), 100e18);
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), 100e18, 'Unexpected GSM GHO before balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), 0, 'Unexpected target GHO before balance');
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit TokensRescued(address(GHO_TOKEN), ALICE, 100e18);
    GHO_GSM.rescueTokens(address(GHO_TOKEN), ALICE, 100e18);
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), 0, 'Unexpected GSM GHO after balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), 100e18, 'Unexpected target GHO after balance');
  }

  function testRescueGhoTokensWithAccruedFees() public {
    GHO_GSM.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    uint256 fee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    assertGt(fee, 0, 'Fee not greater than zero');

    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, fee);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), fee, 'Unexpected GSM GHO balance');

    ghoFaucet(address(GHO_GSM), 1);
    assertEq(GHO_TOKEN.balanceOf(BOB), 0, 'Unexpected target GHO balance before');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), fee + 1, 'Unexpected GSM GHO balance before');

    vm.expectRevert('INSUFFICIENT_GHO_TO_RESCUE');
    GHO_GSM.rescueTokens(address(GHO_TOKEN), BOB, fee);

    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit TokensRescued(address(GHO_TOKEN), BOB, 1);
    GHO_GSM.rescueTokens(address(GHO_TOKEN), BOB, 1);

    assertEq(GHO_TOKEN.balanceOf(BOB), 1, 'Unexpected target GHO balance after');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), fee, 'Unexpected GSM GHO balance after');
  }

  function testRevertRescueGhoTokens() public {
    GHO_GSM.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    vm.expectRevert('INSUFFICIENT_GHO_TO_RESCUE');
    GHO_GSM.rescueTokens(address(GHO_TOKEN), ALICE, 1);
  }

  function testRescueUnderlyingTokens() public {
    GHO_GSM.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    vm.prank(FAUCET);
    USDC_TOKEN.mint(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);

    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected USDC balance before');
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit TokensRescued(address(USDC_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.rescueTokens(address(USDC_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    assertEq(USDC_TOKEN.balanceOf(ALICE), DEFAULT_GSM_USDC_AMOUNT, 'Unexpected USDC balance after');
  }

  function testRescueUnderlyingTokensWithAccruedFees() public {
    GHO_GSM.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    uint256 currentGSMBalance = DEFAULT_GSM_USDC_AMOUNT;
    assertEq(
      USDC_TOKEN.balanceOf(address(GHO_GSM)),
      currentGSMBalance,
      'Unexpected GSM USDC balance before'
    );

    vm.prank(FAUCET);
    USDC_TOKEN.mint(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    assertEq(
      USDC_TOKEN.balanceOf(address(GHO_GSM)),
      currentGSMBalance + DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected GSM USDC balance before, post-mint'
    );
    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected target USDC balance before');

    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit TokensRescued(address(USDC_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.rescueTokens(address(USDC_TOKEN), ALICE, DEFAULT_GSM_USDC_AMOUNT);
    assertEq(
      USDC_TOKEN.balanceOf(address(GHO_GSM)),
      currentGSMBalance,
      'Unexpected GSM USDC balance after'
    );
    assertEq(
      USDC_TOKEN.balanceOf(ALICE),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected target USDC balance after'
    );
  }

  function testRevertRescueUnderlyingTokens() public {
    GHO_GSM.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));

    vm.expectRevert('INSUFFICIENT_EXOGENOUS_ASSET_TO_RESCUE');
    GHO_GSM.rescueTokens(address(USDC_TOKEN), ALICE, 1);
  }

  function testSeize() public {
    assertEq(GHO_GSM.getIsSeized(), false, 'Unexpected seize status before');

    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(USDC_TOKEN.balanceOf(TREASURY), 0, 'Unexpected USDC before token balance');
    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit Seized(
      address(GHO_GSM_LAST_RESORT_LIQUIDATOR),
      BOB,
      DEFAULT_GSM_USDC_AMOUNT,
      DEFAULT_GSM_GHO_AMOUNT
    );
    GHO_GSM.seize();

    assertEq(GHO_GSM.getIsSeized(), true, 'Unexpected seize status after');
    assertEq(
      USDC_TOKEN.balanceOf(TREASURY),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected USDC after token balance'
    );
  }

  function testRevertSeizeWithoutAuthorization() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_LIQUIDATOR_ROLE, address(this)));
    GHO_GSM.seize();
  }

  function testRevertMethodsAfterSeizure() public {
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM.seize();

    vm.expectRevert('GSM_SEIZED_SWAPS_DISABLED');
    GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.expectRevert('GSM_SEIZED_SWAPS_DISABLED');
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.expectRevert('GSM_SEIZED_SWAPS_DISABLED');
    GHO_GSM.seize();
  }

  function testBurnAfterSeize() public {
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM.seize();

    vm.expectRevert('FACILITATOR_BUCKET_LEVEL_NOT_ZERO');
    GHO_TOKEN.removeFacilitator(address(GHO_GSM));

    ghoFaucet(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT);
    vm.startPrank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT);
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit BurnAfterSeize(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT, 0);
    GHO_GSM.burnAfterSeize(DEFAULT_GSM_GHO_AMOUNT);
    vm.stopPrank();

    vm.expectEmit(true, false, false, true, address(GHO_TOKEN));
    emit FacilitatorRemoved(address(GHO_GSM));
    GHO_TOKEN.removeFacilitator(address(GHO_GSM));
  }

  function testBurnAfterSeizeGreaterAmount() public {
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM.seize();

    ghoFaucet(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT + 1);
    vm.startPrank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT + 1);
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit BurnAfterSeize(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT, 0);
    GHO_GSM.burnAfterSeize(DEFAULT_GSM_GHO_AMOUNT + 1);
    vm.stopPrank();
  }

  function testRevertBurnAfterSeizeNotSeized() public {
    vm.expectRevert('GSM_NOT_SEIZED');
    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM.burnAfterSeize(0);
  }

  function testRevertBurnAfterSeizeUnauthorized() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_LIQUIDATOR_ROLE, address(this)));
    GHO_GSM.burnAfterSeize(0);
  }

  function testInjectGho() public {
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    (uint256 excess, uint256 deficit) = GHO_GSM.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');

    // Cut price of the underlying in half to simulate a loss in underlying value
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE / 2,
      address(USDC_TOKEN),
      6
    );
    GHO_GSM.updatePriceStrategy(address(newPriceStrategy));

    GHO_GSM.grantRole(GSM_CONFIGURATOR_ROLE, BOB);

    (excess, deficit) = GHO_GSM.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, DEFAULT_GSM_GHO_AMOUNT / 2, 'Unexpected deficit of GHO');

    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT / 2);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT / 2);
    vm.expectEmit(true, true, false, true, address(GHO_GSM));
    emit BackingProvided(
      BOB,
      address(GHO_TOKEN),
      DEFAULT_GSM_GHO_AMOUNT / 2,
      DEFAULT_GSM_GHO_AMOUNT / 2,
      0
    );
    GHO_GSM.backWith(address(GHO_TOKEN), DEFAULT_GSM_GHO_AMOUNT / 2);
    vm.stopPrank();

    (excess, deficit) = GHO_GSM.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');
  }

  function testInjectUnderlying() public {
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    (uint256 excess, uint256 deficit) = GHO_GSM.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');

    // Cut price of the underlying in half to simulate a loss in underlying value
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE / 2,
      address(USDC_TOKEN),
      6
    );
    GHO_GSM.updatePriceStrategy(address(newPriceStrategy));

    (excess, deficit) = GHO_GSM.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, DEFAULT_GSM_GHO_AMOUNT / 2, 'Unexpected deficit of GHO');

    GHO_GSM.grantRole(GSM_CONFIGURATOR_ROLE, BOB);

    vm.prank(FAUCET);
    USDC_TOKEN.mint(BOB, DEFAULT_GSM_USDC_AMOUNT);
    vm.startPrank(BOB);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, false, true, address(GHO_GSM));
    emit BackingProvided(
      BOB,
      address(USDC_TOKEN),
      DEFAULT_GSM_USDC_AMOUNT,
      DEFAULT_GSM_GHO_AMOUNT / 2,
      0
    );
    GHO_GSM.backWith(address(USDC_TOKEN), DEFAULT_GSM_USDC_AMOUNT);
    vm.stopPrank();

    (excess, deficit) = GHO_GSM.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');
  }

  function testRevertBackWithInvalidAsset() public {
    vm.expectRevert('INVALID_ASSET');
    GHO_GSM.backWith(address(0), 1);
  }

  function testRevertBackWithNotAuthorized() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    vm.prank(ALICE);
    GHO_GSM.backWith(address(GHO_TOKEN), 0);
  }

  function testRevertBackWithZeroAmount() public {
    vm.expectRevert('INVALID_AMOUNT');
    GHO_GSM.backWith(address(GHO_TOKEN), 0);
  }

  function testRevertBackWithNoDeficit() public {
    (uint256 excess, uint256 deficit) = GHO_GSM.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');
    vm.expectRevert('NO_CURRENT_DEFICIT_BACKING');
    GHO_GSM.backWith(address(GHO_TOKEN), 1);
  }

  function testRevertInjectGhoTooMuch() public {
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    (uint256 excess, uint256 deficit) = GHO_GSM.getCurrentBacking();
    assertEq(excess, 0, 'Unexpected excess value of GHO');
    assertEq(deficit, 0, 'Unexpected deficit of GHO');

    GHO_GSM.grantRole(GSM_CONFIGURATOR_ROLE, ALICE);

    // Cut price of the underlying in half to simulate a loss in underlying value
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(
      DEFAULT_FIXED_PRICE / 2,
      address(USDC_TOKEN),
      6
    );
    vm.prank(ALICE);
    GHO_GSM.updatePriceStrategy(address(newPriceStrategy));

    vm.expectRevert('AMOUNT_EXCEEDS_DEFICIT');
    GHO_GSM.backWith(address(GHO_TOKEN), (DEFAULT_GSM_GHO_AMOUNT / 2) + 1);
  }

  function testDistributeFeesToTreasury() public {
    uint256 fee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);

    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit SellAsset(ALICE, ALICE, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT, fee);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), fee, 'Unexpected GSM GHO balance');
    assertEq(GHO_GSM.getAccruedFees(), fee, 'Unexpected GSM accrued fees');

    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit FeesDistributedToTreasury(
      TREASURY,
      address(GHO_TOKEN),
      GHO_TOKEN.balanceOf(address(GHO_GSM))
    );
    GHO_GSM.distributeFeesToTreasury();
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM)),
      0,
      'Unexpected GSM GHO balance post-distribution'
    );
    assertEq(GHO_TOKEN.balanceOf(TREASURY), fee, 'Unexpected GHO balance in treasury');
    assertEq(GHO_GSM.getAccruedFees(), 0, 'Unexpected GSM accrued fees');
  }

  function testDistributeYieldToTreasuryDoNothing() public {
    uint256 gsmBalanceBefore = GHO_TOKEN.balanceOf(address(GHO_GSM));
    uint256 treasuryBalanceBefore = GHO_TOKEN.balanceOf(address(TREASURY));
    assertEq(GHO_GSM.getAccruedFees(), 0, 'Unexpected GSM accrued fees');

    GHO_GSM.distributeFeesToTreasury();

    assertEq(GHO_GSM.getAccruedFees(), 0, 'Unexpected GSM accrued fees');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM)),
      gsmBalanceBefore,
      'Unexpected GSM GHO balance post-distribution'
    );
    assertEq(
      GHO_TOKEN.balanceOf(TREASURY),
      treasuryBalanceBefore,
      'Unexpected GHO balance in treasury'
    );
  }

  function testGetAccruedFees() public {
    assertEq(GHO_GSM.getAccruedFees(), 0, 'Unexpected GSM accrued fees');

    uint256 sellFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 buyFee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_BUY_FEE);

    _sellAsset(GHO_GSM, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), sellFee, 'Unexpected GSM GHO balance');
    assertEq(GHO_GSM.getAccruedFees(), sellFee, 'Unexpected GSM accrued fees');

    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT + buyFee);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit BuyAsset(BOB, BOB, DEFAULT_GSM_USDC_AMOUNT, DEFAULT_GSM_GHO_AMOUNT + buyFee, buyFee);
    GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), sellFee + buyFee, 'Unexpected GSM GHO balance');
    assertEq(GHO_GSM.getAccruedFees(), sellFee + buyFee, 'Unexpected GSM accrued fees');
  }

  function testGetAccruedFeesWithZeroFee() public {
    vm.expectEmit(true, true, false, true, address(GHO_GSM));
    emit FeeStrategyUpdated(address(GHO_GSM_FIXED_FEE_STRATEGY), address(0));
    GHO_GSM.updateFeeStrategy(address(0));

    assertEq(GHO_GSM.getAccruedFees(), 0, 'Unexpected GSM accrued fees');

    for (uint256 i = 0; i < 10; i++) {
      _sellAsset(GHO_GSM, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);
      assertEq(GHO_GSM.getAccruedFees(), 0, 'Unexpected GSM accrued fees');

      ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT);
      vm.startPrank(BOB);
      GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT);
      GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
      vm.stopPrank();

      assertEq(GHO_GSM.getAccruedFees(), 0, 'Unexpected GSM accrued fees');
    }
  }
}

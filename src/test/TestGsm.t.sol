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
    Gsm gsm = new Gsm(
      address(GHO_TOKEN),
      address(USDC_TOKEN),
      address(GHO_GSM_FIXED_PRICE_STRATEGY)
    );
    assertEq(gsm.GHO_TOKEN(), address(GHO_TOKEN), 'Unexpected GHO token address');
    assertEq(gsm.UNDERLYING_ASSET(), address(USDC_TOKEN), 'Unexpected underlying asset address');
    assertEq(
      gsm.PRICE_STRATEGY(),
      address(GHO_GSM_FIXED_PRICE_STRATEGY),
      'Unexpected price strategy'
    );
    assertEq(gsm.getExposureCap(), 0, 'Unexpected exposure capacity');
  }

  function testRevertConstructorInvalidPriceStrategy() public {
    FixedPriceStrategy newPriceStrategy = new FixedPriceStrategy(1e18, address(GHO_TOKEN), 18);
    vm.expectRevert('INVALID_PRICE_STRATEGY');
    new Gsm(address(GHO_TOKEN), address(USDC_TOKEN), address(newPriceStrategy));
  }

  function testRevertConstructorZeroAddressParams() public {
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new Gsm(address(0), address(USDC_TOKEN), address(GHO_GSM_FIXED_PRICE_STRATEGY));

    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    new Gsm(address(GHO_TOKEN), address(0), address(GHO_GSM_FIXED_PRICE_STRATEGY));
  }

  function testInitialize() public {
    Gsm gsm = new Gsm(
      address(GHO_TOKEN),
      address(USDC_TOKEN),
      address(GHO_GSM_FIXED_PRICE_STRATEGY)
    );
    vm.expectEmit(true, true, true, true);
    emit RoleGranted(DEFAULT_ADMIN_ROLE, address(this), address(this));
    vm.expectEmit(true, true, false, true);
    emit GhoTreasuryUpdated(address(0), address(TREASURY));
    vm.expectEmit(true, true, false, true);
    emit ExposureCapUpdated(0, DEFAULT_GSM_USDC_EXPOSURE);
    gsm.initialize(address(this), TREASURY, DEFAULT_GSM_USDC_EXPOSURE, address(GHO_RESERVE));
    assertEq(gsm.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
  }

  function testRevertInitializeZeroAdmin() public {
    Gsm gsm = new Gsm(
      address(GHO_TOKEN),
      address(USDC_TOKEN),
      address(GHO_GSM_FIXED_PRICE_STRATEGY)
    );
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    gsm.initialize(address(0), TREASURY, DEFAULT_GSM_USDC_EXPOSURE, address(GHO_RESERVE));
  }

  function testRevertInitializeZeroGhoReserve() public {
    Gsm gsm = new Gsm(
      address(GHO_TOKEN),
      address(USDC_TOKEN),
      address(GHO_GSM_FIXED_PRICE_STRATEGY)
    );
    vm.expectRevert('ZERO_ADDRESS_NOT_VALID');
    gsm.initialize(address(this), TREASURY, DEFAULT_GSM_USDC_EXPOSURE, address(0));
  }

  function testRevertInitializeTwice() public {
    Gsm gsm = new Gsm(
      address(GHO_TOKEN),
      address(USDC_TOKEN),
      address(GHO_GSM_FIXED_PRICE_STRATEGY)
    );
    gsm.initialize(address(this), TREASURY, DEFAULT_GSM_USDC_EXPOSURE, address(GHO_RESERVE));
    vm.expectRevert('Contract instance has already been initialized');
    gsm.initialize(address(this), TREASURY, DEFAULT_GSM_USDC_EXPOSURE, address(GHO_RESERVE));
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
    (uint256 assetAmount, uint256 ghoBought) = GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(ghoBought, DEFAULT_GSM_GHO_AMOUNT, 'Unexpected GHO amount bought');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount sold');
    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), DEFAULT_GSM_GHO_AMOUNT, 'Unexpected final GHO balance');
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
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
    (uint256 assetAmount, uint256 ghoBought) = GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(ghoBought, DEFAULT_GSM_GHO_AMOUNT - fee, 'Unexpected GHO amount bought');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount sold');
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
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
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
    (uint256 assetAmount, uint256 ghoBought) = GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    assertEq(ghoBought, DEFAULT_GSM_GHO_AMOUNT - fee, 'Unexpected GHO amount bought');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount sold');
    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), 0, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(BOB), ghoOut, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), fee, 'Unexpected GSM GHO balance');
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
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

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        GSM_SELL_ASSET_WITH_SIG_TYPEHASH,
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
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
  }

  function testSellAssetWithSigExactDeadline() public {
    // EIP-2612 states the execution must be allowed in case deadline is equal to block.timestamp
    uint256 deadline = block.timestamp;
    uint256 fee = DEFAULT_GSM_GHO_AMOUNT.percentMul(DEFAULT_GSM_SELL_FEE);
    uint256 ghoOut = DEFAULT_GSM_GHO_AMOUNT - fee;

    vm.prank(FAUCET);
    USDC_TOKEN.mint(gsmSignerAddr, DEFAULT_GSM_USDC_AMOUNT);

    vm.prank(gsmSignerAddr);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);

    assertEq(GHO_GSM.nonces(gsmSignerAddr), 0, 'Unexpected before gsmSignerAddr nonce');

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        GSM_SELL_ASSET_WITH_SIG_TYPEHASH,
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
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
  }

  function testRevertSellAssetWithSigExpiredSignature() public {
    uint256 deadline = block.timestamp - 1;

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        GSM_SELL_ASSET_WITH_SIG_TYPEHASH,
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

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        GSM_SELL_ASSET_WITH_SIG_TYPEHASH,
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
    Gsm gsm = new Gsm(
      address(GHO_TOKEN),
      address(USDC_TOKEN),
      address(GHO_GSM_FIXED_PRICE_STRATEGY)
    );
    gsm.initialize(address(this), TREASURY, DEFAULT_GSM_USDC_EXPOSURE, address(GHO_RESERVE));
    GHO_TOKEN.addFacilitator(address(gsm), 'GSM Modified Bucket Cap', DEFAULT_CAPACITY - 1);
    uint256 defaultCapInUsdc = DEFAULT_CAPACITY / (10 ** (18 - USDC_TOKEN.decimals()));

    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, defaultCapInUsdc);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(gsm), defaultCapInUsdc);
    vm.expectRevert('LIMIT_REACHED');
    gsm.sellAsset(defaultCapInUsdc, ALICE);
    vm.stopPrank();
  }

  function testRevertSellAssetTooMuchUnderlyingExposure() public {
    Gsm gsm = new Gsm(
      address(GHO_TOKEN),
      address(USDC_TOKEN),
      address(GHO_GSM_FIXED_PRICE_STRATEGY)
    );
    gsm.initialize(address(this), TREASURY, DEFAULT_GSM_USDC_EXPOSURE - 1, address(GHO_RESERVE));
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
    (uint256 exactAssetAmount, uint256 ghoBought, uint256 grossAmount, uint256 fee) = GHO_GSM
      .getGhoAmountForSellAsset(DEFAULT_GSM_USDC_AMOUNT);

    _sellAsset(GHO_GSM, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    assertEq(
      DEFAULT_GSM_USDC_AMOUNT - USDC_TOKEN.balanceOf(ALICE),
      exactAssetAmount,
      'Unexpected asset amount sold'
    );
    assertEq(ghoBought + fee, grossAmount, 'Unexpected GHO gross amount');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoBought, 'Unexpected GHO bought amount');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), fee, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 exactGhoBought, uint256 grossAmount2, uint256 fee2) = GHO_GSM
      .getAssetAmountForSellAsset(ghoBought);
    assertEq(GHO_TOKEN.balanceOf(ALICE), exactGhoBought, 'Unexpected GHO bought amount');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected estimation of sold assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testGetGhoAmountForSellAssetWithZeroFee() public {
    GHO_GSM.updateFeeStrategy(address(0));

    (uint256 exactAssetAmount, uint256 ghoBought, uint256 grossAmount, uint256 fee) = GHO_GSM
      .getGhoAmountForSellAsset(DEFAULT_GSM_USDC_AMOUNT);
    assertEq(fee, 0, 'Unexpected GHO fee amount');

    _sellAsset(GHO_GSM, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    assertEq(
      DEFAULT_GSM_USDC_AMOUNT - USDC_TOKEN.balanceOf(ALICE),
      exactAssetAmount,
      'Unexpected asset amount sold'
    );
    assertEq(ghoBought, grossAmount, 'Unexpected GHO gross amount');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoBought, 'Unexpected GHO bought amount');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), 0, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 exactGhoBought, uint256 grossAmount2, uint256 fee2) = GHO_GSM
      .getAssetAmountForSellAsset(ghoBought);
    assertEq(GHO_TOKEN.balanceOf(ALICE), exactGhoBought, 'Unexpected GHO bought amount');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected estimation of sold assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testGetGhoAmountForSellAssetWithZeroAmount() public {
    (uint256 exactAssetAmount, uint256 ghoBought, uint256 grossAmount, uint256 fee) = GHO_GSM
      .getGhoAmountForSellAsset(0);
    assertEq(exactAssetAmount, 0, 'Unexpected exact asset amount');
    assertEq(ghoBought, 0, 'Unexpected GHO bought amount');
    assertEq(grossAmount, 0, 'Unexpected GHO gross amount');
    assertEq(fee, 0, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 exactGhoBought, uint256 grossAmount2, uint256 fee2) = GHO_GSM
      .getAssetAmountForSellAsset(ghoBought);
    assertEq(exactGhoBought, 0, 'Unexpected exact gho bought');
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
    (uint256 assetAmount, uint256 ghoSold) = GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    assertEq(ghoSold, DEFAULT_GSM_GHO_AMOUNT, 'Unexpected GHO amount sold');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount bought');
    assertEq(USDC_TOKEN.balanceOf(BOB), DEFAULT_GSM_USDC_AMOUNT, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), DEFAULT_GSM_GHO_AMOUNT, 'Unexpected final GHO balance');
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
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
    (uint256 assetAmount, uint256 ghoSold) = GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, BOB);
    vm.stopPrank();

    assertEq(ghoSold, DEFAULT_GSM_GHO_AMOUNT + buyFee, 'Unexpected GHO amount sold');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount bought');
    assertEq(USDC_TOKEN.balanceOf(BOB), DEFAULT_GSM_USDC_AMOUNT, 'Unexpected final USDC balance');
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoOut, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), sellFee + buyFee, 'Unexpected GSM GHO balance');
    assertEq(
      GHO_GSM.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE,
      'Unexpected available underlying exposure'
    );
    assertEq(GHO_GSM.getAvailableLiquidity(), 0, 'Unexpected available liquidity');
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
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
    (uint256 assetAmount, uint256 ghoSold) = GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, CHARLES);
    vm.stopPrank();

    assertEq(ghoSold, DEFAULT_GSM_GHO_AMOUNT + buyFee, 'Unexpected GHO amount sold');
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected asset amount bought');
    assertEq(USDC_TOKEN.balanceOf(BOB), 0, 'Unexpected final USDC balance');
    assertEq(
      USDC_TOKEN.balanceOf(CHARLES),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected final USDC balance'
    );
    assertEq(GHO_TOKEN.balanceOf(ALICE), ghoOut, 'Unexpected final GHO balance');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), sellFee + buyFee, 'Unexpected GSM GHO balance');
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
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

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        GSM_BUY_ASSET_WITH_SIG_TYPEHASH,
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
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
  }

  function testBuyAssetWithSigExactDeadline() public {
    // EIP-2612 states the execution must be allowed in case deadline is equal to block.timestamp
    uint256 deadline = block.timestamp;
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

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        GSM_BUY_ASSET_WITH_SIG_TYPEHASH,
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
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
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

    // Buy 1 of the underlying
    GHO_TOKEN.approve(address(GHO_GSM), 1e18);
    vm.expectEmit(true, true, true, true, address(GHO_GSM));
    emit BuyAsset(ALICE, ALICE, 1e6, 1e18, 0);
    GHO_GSM.buyAsset(1e6, ALICE);

    uint256 usedGho = GHO_GSM.getUsedGho();
    assertEq(usedGho, DEFAULT_CAPACITY - 1e18, 'Unexpected GHO bucket level after buy');
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

    usedGho = GHO_GSM.getUsedGho();
    assertEq(usedGho, DEFAULT_CAPACITY, 'Unexpected GHO bucket level after second sell');
    assertEq(
      GHO_TOKEN.balanceOf(ALICE),
      DEFAULT_CAPACITY,
      'Unexpected Alice GHO balance after second sell'
    );
    assertEq(USDC_TOKEN.balanceOf(ALICE), 0, 'Unexpected Alice USDC balance after second sell');
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure capacity');
  }

  function testRevertBuyAssetWithSigExpiredSignature() public {
    uint256 deadline = block.timestamp - 1;

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        GSM_BUY_ASSET_WITH_SIG_TYPEHASH,
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

    bytes32 digest = keccak256(
      abi.encode(
        '\x19\x01',
        GHO_GSM.DOMAIN_SEPARATOR(),
        GSM_BUY_ASSET_WITH_SIG_TYPEHASH,
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
    (uint256 exactAssetAmount, uint256 ghoSold, uint256 grossAmount, uint256 fee) = GHO_GSM
      .getGhoAmountForBuyAsset(DEFAULT_GSM_USDC_AMOUNT);

    uint256 topUpAmount = 1_000_000e18;
    ghoFaucet(ALICE, topUpAmount);

    _sellAsset(GHO_GSM, USDC_TOKEN, ALICE, DEFAULT_GSM_USDC_AMOUNT);

    uint256 ghoBalanceBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 ghoFeesBefore = GHO_TOKEN.balanceOf(address(GHO_GSM));

    vm.startPrank(ALICE);
    GHO_TOKEN.approve(address(GHO_GSM), type(uint256).max);
    GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    assertEq(DEFAULT_GSM_USDC_AMOUNT, exactAssetAmount, 'Unexpected asset amount bought');
    assertEq(ghoSold - fee, grossAmount, 'Unexpected GHO gross sold amount');
    assertEq(ghoBalanceBefore - GHO_TOKEN.balanceOf(ALICE), ghoSold, 'Unexpected GHO sold amount');
    assertEq(
      GHO_TOKEN.balanceOf(address(GHO_GSM)) - ghoFeesBefore,
      fee,
      'Unexpected GHO fee amount'
    );

    (uint256 assetAmount, uint256 exactGhoSold, uint256 grossAmount2, uint256 fee2) = GHO_GSM
      .getAssetAmountForBuyAsset(ghoSold);
    assertEq(
      ghoBalanceBefore - GHO_TOKEN.balanceOf(ALICE),
      exactGhoSold,
      'Unexpected GHO sold exact amount'
    );
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected estimation of bought assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testGetGhoAmountForBuyAssetWithZeroFee() public {
    GHO_GSM.updateFeeStrategy(address(0));

    (uint256 exactAssetAmount, uint256 ghoSold, uint256 grossAmount, uint256 fee) = GHO_GSM
      .getGhoAmountForBuyAsset(DEFAULT_GSM_USDC_AMOUNT);
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

    assertEq(DEFAULT_GSM_USDC_AMOUNT, exactAssetAmount, 'Unexpected asset amount bought');
    assertEq(ghoSold, grossAmount, 'Unexpected GHO gross sold amount');
    assertEq(ghoBalanceBefore - GHO_TOKEN.balanceOf(ALICE), ghoSold, 'Unexpected GHO sold amount');
    assertEq(GHO_TOKEN.balanceOf(address(GHO_GSM)), ghoFeesBefore, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 exactGhoSold, uint256 grossAmount2, uint256 fee2) = GHO_GSM
      .getAssetAmountForBuyAsset(ghoSold);
    assertEq(
      ghoBalanceBefore - GHO_TOKEN.balanceOf(ALICE),
      exactGhoSold,
      'Unexpected GHO sold exact amount'
    );
    assertEq(assetAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected estimation of bought assets');
    assertEq(grossAmount, grossAmount2, 'Unexpected GHO gross amount');
    assertEq(fee, fee2, 'Unexpected GHO fee amount');
  }

  function testGetGhoAmountForBuyAssetWithZeroAmount() public {
    (uint256 exactAssetAmount, uint256 ghoSold, uint256 grossAmount, uint256 fee) = GHO_GSM
      .getGhoAmountForBuyAsset(0);
    assertEq(exactAssetAmount, 0, 'Unexpected exact asset amount');
    assertEq(ghoSold, 0, 'Unexpected GHO sold amount');
    assertEq(grossAmount, 0, 'Unexpected GHO gross amount');
    assertEq(fee, 0, 'Unexpected GHO fee amount');

    (uint256 assetAmount, uint256 exactGhoSold, uint256 grossAmount2, uint256 fee2) = GHO_GSM
      .getAssetAmountForBuyAsset(ghoSold);
    assertEq(exactGhoSold, 0, 'Unexpected exact gho bought');
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
    vm.expectRevert('GSM_FROZEN');
    GHO_GSM.buyAsset(0, ALICE);
    vm.expectRevert('GSM_FROZEN');
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

    address newGhoTreasury = address(GHO_GSM);
    vm.expectEmit(true, true, true, true, address(newGhoTreasury));
    emit GhoTreasuryUpdated(TREASURY, newGhoTreasury);
    GHO_GSM.updateGhoTreasury(newGhoTreasury);
    assertEq(GHO_GSM.getGhoTreasury(), newGhoTreasury);

    vm.expectEmit(true, true, false, true, address(GHO_GSM));
    emit ExposureCapUpdated(DEFAULT_GSM_USDC_EXPOSURE, 0);
    GHO_GSM.updateExposureCap(0);
    assertEq(GHO_GSM.getExposureCap(), 0, 'Unexpected exposure capacity');

    vm.expectEmit(true, true, false, true, address(GHO_GSM));
    emit ExposureCapUpdated(0, 1000);
    GHO_GSM.updateExposureCap(1000);
    assertEq(GHO_GSM.getExposureCap(), 1000, 'Unexpected exposure capacity');

    vm.stopPrank();
  }

  function testRevertConfiguratorUpdateMethodsNotAuthorized() public {
    vm.startPrank(ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(DEFAULT_ADMIN_ROLE, ALICE));
    GHO_GSM.grantRole(GSM_LIQUIDATOR_ROLE, ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(DEFAULT_ADMIN_ROLE, ALICE));
    GHO_GSM.grantRole(GSM_SWAP_FREEZER_ROLE, ALICE);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    GHO_GSM.updateExposureCap(0);
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_CONFIGURATOR_ROLE, ALICE));
    GHO_GSM.updateGhoTreasury(ALICE);
    vm.stopPrank();
  }

  function testRevertInitializeTreasuryZeroAddress() public {
    Gsm gsm = new Gsm(
      address(GHO_TOKEN),
      address(USDC_TOKEN),
      address(GHO_GSM_FIXED_PRICE_STRATEGY)
    );
    vm.expectRevert(bytes('ZERO_ADDRESS_NOT_VALID'));
    gsm.initialize(address(this), address(0), DEFAULT_GSM_USDC_EXPOSURE, address(GHO_RESERVE));
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

  function testRevertRescueTokensZeroAmount() public {
    GHO_GSM.grantRole(GSM_TOKEN_RESCUER_ROLE, address(this));
    vm.expectRevert('INVALID_AMOUNT');
    GHO_GSM.rescueTokens(address(WETH), ALICE, 0);
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
    uint256 seizedAmount = GHO_GSM.seize();

    assertEq(GHO_GSM.getIsSeized(), true, 'Unexpected seize status after');
    assertEq(seizedAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected seized amount');
    assertEq(
      USDC_TOKEN.balanceOf(TREASURY),
      DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected USDC after token balance'
    );
    assertEq(GHO_GSM.getAvailableLiquidity(), 0, 'Unexpected available liquidity');
    assertEq(
      GHO_GSM.getAvailableUnderlyingExposure(),
      0,
      'Unexpected underlying exposure available'
    );
    assertEq(GHO_GSM.getExposureCap(), 0, 'Unexpected exposure capacity');
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
    uint256 seizedAmount = GHO_GSM.seize();
    assertEq(seizedAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected seized amount');

    vm.expectRevert('GSM_SEIZED');
    GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.expectRevert('GSM_SEIZED');
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.expectRevert('GSM_SEIZED');
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
    uint256 seizedAmount = GHO_GSM.seize();
    assertEq(seizedAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected seized amount');

    uint256 usedGho = GHO_GSM.getUsedGho();
    assertTrue(usedGho > 0, 'Unexpected usedGho amount');

    vm.expectRevert('FACILITATOR_BUCKET_LEVEL_NOT_ZERO');
    GHO_TOKEN.removeFacilitator(address(OWNABLE_FACILITATOR));

    ghoFaucet(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT);
    vm.startPrank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT);
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit BurnAfterSeize(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT, 0);
    uint256 burnedAmount = GHO_GSM.burnAfterSeize(DEFAULT_GSM_GHO_AMOUNT);
    vm.stopPrank();
    assertEq(burnedAmount, DEFAULT_GSM_GHO_AMOUNT, 'Unexpected burned amount of GHO');
    assertEq(GHO_GSM.getUsedGho(), 0, 'Unexpected amount of used GHO');
  }

  function testBurnAfterSeizeGreaterAmount() public {
    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, DEFAULT_GSM_USDC_AMOUNT);

    vm.startPrank(ALICE);
    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);
    vm.stopPrank();

    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    uint256 seizedAmount = GHO_GSM.seize();
    assertEq(seizedAmount, DEFAULT_GSM_USDC_AMOUNT, 'Unexpected seized amount');

    ghoFaucet(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT + 1);
    vm.startPrank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT + 1);
    vm.expectEmit(true, false, false, true, address(GHO_GSM));
    emit BurnAfterSeize(address(GHO_GSM_LAST_RESORT_LIQUIDATOR), DEFAULT_GSM_GHO_AMOUNT, 0);
    uint256 burnedAmount = GHO_GSM.burnAfterSeize(DEFAULT_GSM_GHO_AMOUNT + 1);
    vm.stopPrank();
    assertEq(burnedAmount, DEFAULT_GSM_GHO_AMOUNT, 'Unexpected burned amount of GHO');
  }

  function testRevertBurnAfterSeizeNotSeized() public {
    vm.expectRevert('GSM_NOT_SEIZED');
    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM.burnAfterSeize(1);
  }

  function testRevertBurnAfterInvalidAmount() public {
    vm.startPrank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM_4626.seize();
    vm.expectRevert('INVALID_AMOUNT');
    GHO_GSM_4626.burnAfterSeize(0);
    vm.stopPrank();
  }

  function testRevertBurnAfterSeizeUnauthorized() public {
    vm.expectRevert(AccessControlErrorsLib.MISSING_ROLE(GSM_LIQUIDATOR_ROLE, address(this)));
    GHO_GSM.burnAfterSeize(1);
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

    vm.record();
    GHO_GSM.distributeFeesToTreasury();
    (, bytes32[] memory writes) = vm.accesses(address(GHO_GSM));
    assertEq(writes.length, 0, 'Unexpected update of accrued fees');

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

  function testCanSwap() public {
    assertEq(GHO_GSM.canSwap(), true, 'Unexpected initial swap state');

    // Freeze the GSM
    vm.startPrank(address(GHO_GSM_SWAP_FREEZER));
    GHO_GSM.setSwapFreeze(true);
    assertEq(GHO_GSM.canSwap(), false, 'Unexpected swap state post-freeze');

    // Unfreeze the GSM
    GHO_GSM.setSwapFreeze(false);
    assertEq(GHO_GSM.canSwap(), true, 'Unexpected swap state post-unfreeze');
    vm.stopPrank();

    // Seize the GSM
    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GHO_GSM.seize();
    assertEq(GHO_GSM.canSwap(), false, 'Unexpected swap state post-seize');
  }

  function testUpdateExposureCapBelowCurrentExposure() public {
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure cap');

    vm.prank(FAUCET);
    USDC_TOKEN.mint(ALICE, 2 * DEFAULT_GSM_USDC_AMOUNT);

    // Alice as configurator
    GHO_GSM.grantRole(GSM_CONFIGURATOR_ROLE, ALICE);
    vm.startPrank(address(ALICE));

    GHO_GSM.updateFeeStrategy(address(0));

    USDC_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_USDC_AMOUNT);
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);

    assertEq(
      GHO_GSM.getAvailableUnderlyingExposure(),
      DEFAULT_GSM_USDC_EXPOSURE - DEFAULT_GSM_USDC_AMOUNT,
      'Unexpected available underlying exposure'
    );
    assertEq(GHO_GSM.getExposureCap(), DEFAULT_GSM_USDC_EXPOSURE, 'Unexpected exposure cap');

    // Update exposure cap to smaller value than current exposure
    uint256 currentExposure = GHO_GSM.getAvailableLiquidity();
    uint256 newExposureCap = currentExposure - 1;
    GHO_GSM.updateExposureCap(uint128(newExposureCap));
    assertEq(GHO_GSM.getExposureCap(), newExposureCap, 'Unexpected exposure cap');
    assertEq(GHO_GSM.getAvailableLiquidity(), currentExposure, 'Unexpected current exposure');

    // Reducing exposure to 0
    GHO_GSM.updateExposureCap(0);

    // Sell cannot be executed
    vm.expectRevert('EXOGENOUS_ASSET_EXPOSURE_TOO_HIGH');
    GHO_GSM.sellAsset(DEFAULT_GSM_USDC_AMOUNT, ALICE);

    // Buy some asset to reduce current exposure
    vm.stopPrank();
    ghoFaucet(BOB, DEFAULT_GSM_GHO_AMOUNT / 2);
    vm.startPrank(BOB);
    GHO_TOKEN.approve(address(GHO_GSM), DEFAULT_GSM_GHO_AMOUNT / 2);
    GHO_GSM.buyAsset(DEFAULT_GSM_USDC_AMOUNT / 2, BOB);

    assertEq(GHO_GSM.getExposureCap(), 0, 'Unexpected exposure capacity');
  }
}
